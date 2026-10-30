import test from "node:test";
import assert from "node:assert/strict";
import { gameTotals } from "../../app/frontend/lib/gameTotals.ts";
import { invoiceTotal } from "../../app/frontend/lib/money.ts";

test("comparison includes linked games from every page and ignores unlinked games", () => {
  const known = new Map(
    Array.from({ length: 32 }, (_, index) => [index + 1, { fees_cents: 1337 }]),
  );
  const linked = Array.from({ length: 30 }, (_, index) => index + 1);
  const invoice = invoiceTotal([
    { quantity: "30", rate: "13.37" },
    { quantity: "1", rate: "25.50" },
    { quantity: "4", rate: "100", _destroy: true },
  ]);
  assert.deepEqual(gameTotals(linked, known, invoice), {
    count: 30,
    feesCents: 40110,
    differenceCents: 2550,
  });
  assert.deepEqual(
    gameTotals([...linked, 1], known, invoice),
    gameTotals(linked, known, invoice),
  );
  assert.equal(
    gameTotals(linked.slice(0, -1), known, invoice).differenceCents,
    3887,
  );
});

test("comparison distinguishes a shortfall, exact match and no linked games", () => {
  const known = new Map([[1, { fees_cents: 25000 }]]);
  assert.equal(gameTotals([1], known, 20000).differenceCents, -5000);
  assert.equal(gameTotals([1], known, 25000).differenceCents, 0);
  assert.deepEqual(gameTotals([], known, 25000), {
    count: 0,
    feesCents: 0,
    differenceCents: null,
  });
});

test("missing game summaries cannot produce a misleading match or partial total", () => {
  const known = new Map([[1, { fees_cents: 25000 }]]);
  assert.deepEqual(gameTotals([1, 2], known, 25000), {
    count: 2,
    feesCents: null,
    differenceCents: null,
  });
});
