import type { EditableLineItem, PrivateBreakdown } from "../types";
import { lineTotal, scaled } from "./money.ts";

export function breakdownTotal(
  entries: PrivateBreakdown["entries"],
): number | null {
  if (
    !entries.length ||
    entries.some((entry) => !/^\d{1,6}(?:\.\d{1,2})?$/.test(entry.amount))
  )
    return null;
  const cents = entries.reduce(
    (sum, entry) => sum + scaled(entry.amount, 2),
    0n,
  );
  return cents <= 99999999n ? Number(cents) : null;
}

export function applyBreakdownTotal(item: EditableLineItem): EditableLineItem {
  const total = breakdownTotal(item.private_breakdown?.entries ?? []);
  return total === null
    ? item
    : {
        ...item,
        amount_only: true,
        quantity: "1",
        rate: (total / 100).toFixed(2),
      };
}

export function moveLineItem(
  items: EditableLineItem[],
  index: number,
  direction: -1 | 1,
) {
  const visible = items.flatMap((item, position) =>
    item._destroy ? [] : [position],
  );
  const current = visible.indexOf(index);
  const target = visible[current + direction];
  if (current === -1 || target === undefined) return items;
  return moveLineItemTo(items, index, target);
}

export function moveLineItemTo(
  items: EditableLineItem[],
  from: number,
  to: number,
) {
  if (
    !items[from] ||
    !items[to] ||
    items[from]._destroy ||
    items[to]._destroy ||
    from === to
  )
    return items;

  const positions = items.flatMap((item, index) =>
    item._destroy ? [] : [index],
  );
  const reordered = positions.map((index) => items[index]);
  const [item] = reordered.splice(positions.indexOf(from), 1);
  reordered.splice(positions.indexOf(to), 0, item);
  let next = 0;
  return items.map((original, position) => ({
    ...(original._destroy ? original : reordered[next++]),
    position,
  }));
}

export function changeLinePricing(
  item: EditableLineItem,
  amountOnly: boolean,
): EditableLineItem {
  if (Boolean(item.amount_only) === amountOnly) return item;
  return {
    ...item,
    amount_only: amountOnly,
    quantity: "1",
    rate:
      amountOnly &&
      /^\d+(?:\.\d{0,3})?$/.test(item.quantity) &&
      /^\d+(?:\.\d{0,2})?$/.test(item.rate)
        ? (lineTotal(item.quantity, item.rate) / 100).toFixed(2)
        : item.rate,
  };
}
