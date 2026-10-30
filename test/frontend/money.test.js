import test from "node:test";
import assert from "node:assert/strict";
import { invoiceTotal, lineTotal } from "../../app/frontend/lib/money.ts";

test("line totals round half cents exactly, matching Rails decimal calculations", () => {
  assert.equal(lineTotal("2.5", "13.37"), 3343);
  assert.equal(lineTotal("0.005", "1.00"), 1);
  assert.equal(lineTotal("0.004", "1.00"), 0);
  assert.equal(lineTotal("3", "0.10"), 30);
});
test("removing a persisted line excludes its amount and blank or invalid values are safe", () => {
  assert.equal(
    invoiceTotal([
      { quantity: "2", rate: "10.25" },
      { quantity: "9", rate: "20", _destroy: true },
      { quantity: "", rate: "" },
    ]),
    2050,
  );
  assert.equal(lineTotal("1.0001", "10"), 0);
  assert.equal(lineTotal("1", "10.001"), 0);
});

test("amount-only charges ignore quantity and combine with quantity-based lines", () => {
  assert.equal(
    invoiceTotal([
      { quantity: "2.5", rate: "13.37" },
      { quantity: "", rate: "24.75", amount_only: true },
      { quantity: "99", rate: "5.00", amount_only: true },
      { quantity: "1", rate: "100.00", amount_only: true, _destroy: true },
    ]),
    6318,
  );
});
