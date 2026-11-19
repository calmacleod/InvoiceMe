import type { EditableLineItem } from "../types";
import { useState } from "react";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../styles/ui.stylex";
import { Field } from "./UI";
import {
  moveLineItem,
  moveLineItemTo,
  changeLinePricing,
} from "../lib/lineItems";
import LineItemBreakdown from "./LineItemBreakdown";

export default function InvoiceLineItems({
  items,
  onChange,
}: {
  items: EditableLineItem[];
  onChange: (items: EditableLineItem[]) => void;
}) {
  const [dragged, setDragged] = useState<number | null>(null);
  const [dropTarget, setDropTarget] = useState<number | null>(null);
  const clearDrag = () => {
    setDragged(null);
    setDropTarget(null);
  };
  const visible = items
    .map((item, index) => ({ item, index }))
    .filter(({ item }) => !item._destroy);
  const changeLine = <Key extends keyof EditableLineItem>(
    index: number,
    key: Key,
    value: EditableLineItem[Key],
  ) =>
    onChange(
      items.map((item, position) =>
        position === index ? { ...item, [key]: value } : item,
      ),
    );
  const addLine = (amountOnly: boolean) =>
    onChange([
      ...items,
      {
        key: crypto.randomUUID(),
        description: "",
        quantity: "1",
        rate: "",
        amount_only: amountOnly,
        position: items.length,
        _destroy: false,
      },
    ]);
  return (
    <>
      <div {...stylex.props(ui.lineItems)}>
        {visible.map(({ item, index }, row) => (
          <div
            {...stylex.props(
              ui.lineRow,
              index === dragged && ui.lineDragging,
              index === dropTarget &&
                dragged !== null &&
                (dragged < index ? ui.lineDropAfter : ui.lineDropBefore),
            )}
            key={item.key}
            role="group"
            aria-label={`Line item ${row + 1}`}
            onDragOver={(event) => {
              if (dragged === null) return;
              event.preventDefault();
              event.dataTransfer.dropEffect = "move";
              setDropTarget(dragged === index ? null : index);
            }}
            onDrop={(event) => {
              if (dragged === null) return;
              event.preventDefault();
              onChange(moveLineItemTo(items, dragged, index));
              clearDrag();
            }}
          >
            <div {...stylex.props(ui.lineDescription)}>
              <Field
                name={`description-${index}`}
                label="Description"
                value={item.description}
                onChange={(value) => changeLine(index, "description", value)}
                required
              />
            </div>
            <div>
              <label {...stylex.props(ui.label)} htmlFor={`pricing-${index}`}>
                Pricing
              </label>
              <select
                {...stylex.props(ui.input)}
                id={`pricing-${index}`}
                value={item.amount_only ? "amount" : "quantity"}
                onChange={(event) =>
                  onChange(
                    items.map((line, position) =>
                      position === index
                        ? changeLinePricing(
                            line,
                            event.target.value === "amount",
                          )
                        : line,
                    ),
                  )
                }
              >
                <option value="quantity">Quantity × rate</option>
                <option value="amount">Amount only</option>
              </select>
            </div>
            {item.amount_only ? (
              <span aria-hidden="true" />
            ) : (
              <Field
                name={`quantity-${index}`}
                label="Quantity"
                type="number"
                value={item.quantity}
                onChange={(value) => changeLine(index, "quantity", value)}
                step="0.001"
                min="0.001"
                max="999999.999"
                required
              />
            )}
            <Field
              name={`rate-${index}`}
              label={item.amount_only ? "Amount (CAD)" : "Rate (CAD)"}
              type="number"
              value={item.rate}
              onChange={(value) => changeLine(index, "rate", value)}
              step="0.01"
              min="0"
              max="999999.99"
              required
            />
            <div {...stylex.props(ui.lineActions)}>
              {visible.length > 1 && (
                <span
                  {...stylex.props(ui.lineGrip)}
                  draggable
                  aria-hidden="true"
                  title="Drag to reorder"
                  onDragStart={(event) => {
                    event.dataTransfer.setData("text/plain", String(index));
                    event.dataTransfer.effectAllowed = "move";
                    setDragged(index);
                  }}
                  onDragEnd={clearDrag}
                >
                  <span>⠿</span>
                </span>
              )}
              <button
                type="button"
                {...stylex.props(ui.nativeButton, ui.button, ui.lineAction)}
                aria-label={`Move line item ${row + 1} up`}
                title="Move up"
                disabled={row === 0}
                onClick={() => onChange(moveLineItem(items, index, -1))}
              >
                ↑
              </button>
              <button
                type="button"
                {...stylex.props(ui.nativeButton, ui.button, ui.lineAction)}
                aria-label={`Move line item ${row + 1} down`}
                title="Move down"
                disabled={row === visible.length - 1}
                onClick={() => onChange(moveLineItem(items, index, 1))}
              >
                ↓
              </button>
              <button
                type="button"
                {...stylex.props(ui.nativeButton, ui.button, ui.lineAction)}
                aria-label={`Remove line item ${row + 1}`}
                title="Remove line item"
                onClick={() => changeLine(index, "_destroy", true)}
              >
                ×
              </button>
            </div>
            <LineItemBreakdown
              item={item}
              row={row + 1}
              onChange={(updated) =>
                onChange(
                  items.map((line, position) =>
                    position === index ? updated : line,
                  ),
                )
              }
            />
          </div>
        ))}
      </div>
      <div {...stylex.props(ui.actions)}>
        <button
          {...stylex.props(ui.nativeButton, ui.button)}
          type="button"
          onClick={() => addLine(false)}
        >
          + Add line item
        </button>
        <button
          {...stylex.props(ui.nativeButton, ui.button)}
          type="button"
          onClick={() => addLine(true)}
        >
          + Add amount-only item
        </button>
      </div>
    </>
  );
}
