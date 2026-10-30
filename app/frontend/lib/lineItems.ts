import type { EditableLineItem } from "../types";
import { lineTotal } from "./money.ts";

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
  const reordered = [...items];
  [reordered[index], reordered[target]] = [reordered[target], reordered[index]];
  return reordered.map((item, position) => ({ ...item, position }));
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
