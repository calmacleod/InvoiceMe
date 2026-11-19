import test from "node:test";
import assert from "node:assert/strict";
import {
  moveLineItem,
  moveLineItemTo,
  changeLinePricing,
  breakdownTotal,
  applyBreakdownTotal,
} from "../../app/frontend/lib/lineItems.ts";
import { invoiceTotal } from "../../app/frontend/lib/money.ts";

test("a long move shifts intervening lines and preserves pending deletions", () => {
  const items = Array.from({ length: 5 }, (_, position) => ({
    id: position + 1,
    key: position + 1,
    description: `Example ${position + 1}`,
    quantity: "1",
    rate: "20.00",
    position,
    _destroy: position === 2,
  }));
  const moved = moveLineItemTo(items, 0, 4);
  assert.deepEqual(
    moved.map(({ id }) => id),
    [2, 4, 3, 5, 1],
  );
  assert.deepEqual(
    moved.map(({ position }) => position),
    [0, 1, 2, 3, 4],
  );
  assert.equal(moved[2]._destroy, true);
  assert.equal(invoiceTotal(moved), invoiceTotal(items));
  assert.deepEqual(moveLineItemTo(moved, 4, 0), items);
});

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

test("private breakdown totals use exact cents and can be applied without losing notes", () => {
  const item = {
    key: "travel",
    description: "Travel",
    quantity: "2",
    rate: "100",
    position: 0,
    _destroy: false,
    private_breakdown: {
      notes: "Private reminder",
      entries: [
        { key: "a", description: "Trip A", amount: "20.10" },
        { key: "b", description: "Trip B", amount: "0.20" },
      ],
    },
  };
  assert.equal(breakdownTotal(item.private_breakdown.entries), 2030);
  const updated = applyBreakdownTotal(item);
  assert.equal(updated.rate, "20.30");
  assert.equal(updated.quantity, "1");
  assert.equal(updated.amount_only, true);
  assert.equal(updated.private_breakdown.notes, "Private reminder");
  assert.equal(
    breakdownTotal([{ key: "a", description: "", amount: "" }]),
    null,
  );
  assert.equal(
    breakdownTotal([{ key: "a", description: "", amount: "3.999" }]),
    null,
  );
  assert.equal(
    breakdownTotal([
      { key: "a", description: "", amount: "999999.99" },
      { key: "b", description: "", amount: "0.01" },
    ]),
    null,
  );
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
