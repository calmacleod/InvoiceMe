import * as stylex from "@stylexjs/stylex";
import type { EditableLineItem, PrivateBreakdown } from "../types";
import { applyBreakdownTotal, breakdownTotal } from "../lib/lineItems";
import { money } from "../lib/format";
import { lineTotal } from "../lib/money";
import { ui } from "../styles/ui.stylex";
import { Field } from "./UI";

export default function LineItemBreakdown({
  item,
  row,
  onChange,
}: {
  item: EditableLineItem;
  row: number;
  onChange: (item: EditableLineItem) => void;
}) {
  const breakdown = item.private_breakdown ?? { notes: "", entries: [] };
  const total = breakdownTotal(breakdown.entries);
  const change = (next: PrivateBreakdown) =>
    onChange({ ...item, private_breakdown: next });
  return (
    <details {...stylex.props(ui.breakdown)}>
      <summary>
        Private breakdown and notes
        {breakdown.entries.length > 0 ? ` (${breakdown.entries.length})` : ""}
      </summary>
      <p {...stylex.props(ui.hint)}>
        Only you can see these details. They do not appear on the invoice.
      </p>
      <div {...stylex.props(ui.breakdownRows)}>
        {breakdown.entries.map((entry, index) => (
          <div {...stylex.props(ui.breakdownRow)} key={entry.key}>
            <Field
              name={`breakdown-${item.key}-${index}-description`}
              label="Description or note"
              value={entry.description}
              onChange={(description) =>
                change({
                  ...breakdown,
                  entries: breakdown.entries.map((part, i) =>
                    i === index ? { ...part, description } : part,
                  ),
                })
              }
              maxLength={1000}
            />
            <Field
              name={`breakdown-${item.key}-${index}-amount`}
              label="Amount (CAD)"
              type="number"
              step="0.01"
              min="0"
              max="999999.99"
              value={entry.amount}
              onChange={(amount) =>
                change({
                  ...breakdown,
                  entries: breakdown.entries.map((part, i) =>
                    i === index ? { ...part, amount } : part,
                  ),
                })
              }
            />
            <button
              type="button"
              {...stylex.props(ui.nativeButton, ui.button, ui.lineAction)}
              aria-label={`Remove breakdown entry ${index + 1} from line item ${row}`}
              onClick={() =>
                change({
                  ...breakdown,
                  entries: breakdown.entries.filter((_, i) => i !== index),
                })
              }
            >
              Remove
            </button>
          </div>
        ))}
        <div {...stylex.props(ui.actions)}>
          <button
            type="button"
            {...stylex.props(ui.nativeButton, ui.button, ui.lineAction)}
            onClick={() =>
              change({
                ...breakdown,
                entries: [
                  ...breakdown.entries,
                  { key: crypto.randomUUID(), description: "", amount: "" },
                ],
              })
            }
          >
            + Add breakdown entry
          </button>
          <span aria-live="polite">
            Breakdown total:{" "}
            {total === null ? "Enter valid amounts" : money(total)}
          </span>
          <button
            type="button"
            {...stylex.props(ui.nativeButton, ui.button, ui.lineAction)}
            disabled={total === null}
            onClick={() => onChange(applyBreakdownTotal(item))}
          >
            Use total for line item
          </button>
        </div>
        {total !== null &&
          total !==
            lineTotal(item.amount_only ? "1" : item.quantity, item.rate) && (
            <p {...stylex.props(ui.hint)}>
              The breakdown differs from the line item. Use the total above to
              update the invoice amount.
            </p>
          )}
        <Field
          name={`breakdown-${item.key}-notes`}
          label="Private notes"
          multiline
          rows={2}
          maxLength={10000}
          value={breakdown.notes}
          onChange={(notes) => change({ ...breakdown, notes })}
        />
      </div>
    </details>
  );
}
