import test from "node:test";
import assert from "node:assert/strict";
import {
  DraftSaver,
  DraftSaveError,
} from "../../app/frontend/lib/draftSaver.ts";

const identity = {
  id: 1,
  client_key: "example",
  season_id: 1,
  invoice_id: null,
  lock_version: 0,
};
const initial = { number_suffix: "", recipient: "", line_items_attributes: [] };
const metadata = (revision) => ({
  ...identity,
  lock_version: revision,
  updated_at: "2031-02-17T00:00:00Z",
  title: "Example",
});

test("serializes requests and saves the latest edit made during an in-flight request", async () => {
  const requests = [];
  const resolve = [];
  const saver = new DraftSaver(
    identity,
    initial,
    (id, data) =>
      new Promise((done) => {
        requests.push({ id, data });
        resolve.push(done);
      }),
    () => {},
  );
  saver.change({ ...initial, recipient: "First fictional club" });
  const first = saver.flush();
  saver.change({ ...initial, recipient: "Second fictional club" });
  const second = saver.flush();
  assert.equal(requests.length, 1);
  resolve[0](metadata(1));
  await new Promise((done) => setImmediate(done));
  assert.equal(requests.length, 2);
  assert.equal(requests[1].id.lock_version, 1);
  assert.equal(requests[1].data.recipient, "Second fictional club");
  resolve[1](metadata(2));
  await Promise.all([first, second]);
  assert.equal(saver.dirty, false);
  assert.equal(saver.identity.lock_version, 2);
});

test("a lost save acknowledgement retries the same snapshot before sending newer edits", async () => {
  const requests = [];
  let fail = true;
  const saver = new DraftSaver(
    identity,
    initial,
    async (id, data) => {
      requests.push({ id, data });
      if (fail) {
        fail = false;
        throw new Error("Example network interruption");
      }
      return metadata(requests.length - 1);
    },
    () => {},
  );
  saver.change({ ...initial, recipient: "First fictional club" });
  await assert.rejects(saver.flush());
  saver.change({ ...initial, recipient: "Latest fictional club" });
  await saver.flush();
  assert.equal(requests[1].data.recipient, "First fictional club");
  assert.equal(requests[1].id.lock_version, 0);
  assert.equal(requests[2].data.recipient, "Latest fictional club");
  assert.equal(requests[2].id.lock_version, 1);
  assert.equal(saver.dirty, false);
});

test("conflicts preserve unsaved data and expose an error instead of overwriting", async () => {
  let state;
  const saver = new DraftSaver(
    identity,
    initial,
    async () => {
      throw new DraftSaveError("Changed elsewhere", 409);
    },
    (next) => {
      state = next;
    },
  );
  saver.change({ ...initial, recipient: "Unsaved fictional club" });
  await assert.rejects(saver.flush());
  assert.equal(saver.dirty, true);
  assert.equal(JSON.parse(saver.latest).recipient, "Unsaved fictional club");
  assert.equal(state.conflict, true);
});

test("no-op flush does not write, while an explicitly previewed blank draft gets an identity", async () => {
  let requests = 0;
  const saver = new DraftSaver(
    { ...identity, id: null },
    initial,
    async () => {
      requests += 1;
      return metadata(0);
    },
    () => {},
  );
  await saver.flush();
  assert.equal(requests, 0);
  await saver.flush(true);
  assert.equal(requests, 1);
  assert.equal(saver.identity.id, 1);
});

test("a rejected payload can be corrected without retrying the invalid snapshot forever", async () => {
  const requests = [];
  const saver = new DraftSaver(
    identity,
    initial,
    async (_id, data) => {
      requests.push(data);
      if (requests.length === 1)
        throw new DraftSaveError("Example validation error", 422);
      return metadata(1);
    },
    () => {},
  );
  saver.change({ ...initial, recipient: "Invalid example" });
  await assert.rejects(saver.flush());
  saver.change({ ...initial, recipient: "Corrected fictional club" });
  await saver.flush();
  assert.equal(requests[1].recipient, "Corrected fictional club");
  assert.equal(saver.dirty, false);
});
