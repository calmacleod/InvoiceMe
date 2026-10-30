import test from "node:test";
import assert from "node:assert/strict";
import {
  moveLineItem,
  changeLinePricing,
} from "../../app/frontend/lib/lineItems.ts";
import { invoiceTotal } from "../../app/frontend/lib/money.ts";

test("reordering skips removed rows while retaining saved IDs, deletions and total", () => {
  const items = [
    {
      id: 1,
      key: 1,
      description: "Example service",
      quantity: "2",
      rate: "13.37",
      position: 0,
      _destroy: false,
    },
    {
      id: 2,
      key: 2,
      description: "Removed example",
      quantity: "1",
      rate: "100",
      position: 1,
      _destroy: true,
    },
    {
      key: "example-travel",
      description: "Example travel",
      quantity: "1",
      rate: "24.75",
      amount_only: true,
      position: 2,
      _destroy: false,
    },
  ];
  const moved = moveLineItem(items, 2, -1);
  assert.deepEqual(
    moved.map((item) => item.key),
    ["example-travel", 2, 1],
  );
  assert.deepEqual(
    moved.map((item) => item.position),
    [0, 1, 2],
  );
  assert.equal(moved[1]._destroy, true);
  assert.equal(moved[2].id, 1);
  assert.equal(items[0].key, 1);
  assert.equal(invoiceTotal(moved), invoiceTotal(items));
  assert.equal(moveLineItem(items, 0, -1), items);
  assert.equal(moveLineItem(items, 2, 1), items);
  assert.equal(moveLineItem(items, 1, -1), items);
  assert.deepEqual(moveLineItem(moved, 0, 1), items);
});

test("switching pricing retains the rounded charge and keeps invalid amounts visible", () => {
  const item = {
    key: "example",
    description: "Example",
    quantity: "2.5",
    rate: "13.37",
    position: 0,
    _destroy: false,
  };
  const amount = changeLinePricing(item, true);
  assert.equal(amount.quantity, "1");
  assert.equal(amount.rate, "33.43");
  assert.equal(amount.amount_only, true);
  assert.equal(invoiceTotal([item]), invoiceTotal([amount]));
  const quantity = changeLinePricing(amount, false);
  assert.equal(quantity.quantity, "1");
  assert.equal(quantity.rate, "33.43");
  assert.equal(quantity.amount_only, false);
  assert.equal(
    changeLinePricing({ ...item, rate: "10.005" }, true).rate,
    "10.005",
  );
});
