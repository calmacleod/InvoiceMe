import { Head, useForm } from "@inertiajs/react";
import * as stylex from "@stylexjs/stylex";
import { useState } from "react";
import Link from "../../components/AppLink";
import { Errors, Heading } from "../../components/UI";
import { ui } from "../../styles/ui.stylex";
import { register } from "./register.stylex";

type Item = { label: string; amount: string };
type Row = Item & { key: number; officialId: number | null };
type Payment = {
  id: number;
  name: string;
  payment_number: number;
  lock_version: number;
  locked: boolean;
  adjustments: { label: string; amount_cents: number }[];
};
type Update = { id: number; lock_version: number; items: Item[] };

function savedItems(payment: Payment): Item[] {
  return payment.adjustments.map(({ label, amount_cents }) => ({
    label,
    amount: (amount_cents / 100).toFixed(2),
  }));
}

function editRows(payments: Payment[]): Row[] {
  return payments
    .flatMap((payment) =>
      savedItems(payment).map((item) => ({ ...item, officialId: payment.id })),
    )
    .map((row, key) => ({ ...row, key }));
}

export default function Adjustments({
  year,
  payments,
}: {
  year: number;
  payments: Payment[];
}) {
  const form = useForm<{ payments: Update[] }>({ payments: [] });
  const [original, setOriginal] = useState(payments);
  const [rows, setRows] = useState(() => editRows(payments));
  const officials = new Map(payments.map((payment) => [payment.id, payment]));
  const grouped = new Map<number, Item[]>();
  let incomplete = false;
  for (const { officialId, label, amount } of rows) {
    if (!label.trim() && !amount.trim()) continue;
    if (officialId === null || !label.trim() || !amount.trim()) {
      incomplete = true;
      continue;
    }
    const items = grouped.get(officialId) ?? [];
    items.push({ label, amount });
    grouped.set(officialId, items);
  }
  const changes = original.flatMap((payment) => {
    const items = grouped.get(payment.id) ?? [];
    return JSON.stringify(items) === JSON.stringify(savedItems(payment))
      ? []
      : [{ id: payment.id, lock_version: payment.lock_version, items }];
  });

  const updateRow = (key: number, attrs: Partial<Row>) =>
    setRows((current) =>
      current.map((row) => (row.key === key ? { ...row, ...attrs } : row)),
    );

  return (
    <>
      <Head title="Additional payment items" />
      <Link {...stylex.props(ui.link)} href="/official_payments">
        ← Officials payments
      </Link>
      <Heading title="Additional items">
        Enter named credits and deductions for any official in {year}. Use a
        negative amount for a deduction.
      </Heading>
      <Errors errors={form.errors} />
      <form
        onSubmit={(event) => {
          event.preventDefault();
          form.transform(() => ({ payments: changes }));
          form.patch("/official_payments/update_adjustments", {
            onSuccess: (page) => {
              const saved = page.props.payments as Payment[];
              setOriginal(saved);
              setRows(editRows(saved));
            },
          });
        }}
      >
        <section {...stylex.props(ui.card, ui.tableCard)}>
          <div {...stylex.props(ui.tableScroll, register.scroll)}>
            <table {...stylex.props(ui.table, register.table)}>
              <thead>
                <tr>
                  <th scope="col" {...stylex.props(ui.th, register.header)}>
                    Official
                  </th>
                  <th scope="col" {...stylex.props(ui.th, register.header)}>
                    Item / reason
                  </th>
                  <th
                    scope="col"
                    {...stylex.props(ui.th, register.header, ui.numeric)}
                  >
                    Amount
                  </th>
                  <th scope="col" {...stylex.props(ui.th, register.header)}>
                    Action
                  </th>
                </tr>
              </thead>
              <tbody>
                {rows.map((row, index) => {
                  const locked =
                    row.officialId !== null &&
                    Boolean(officials.get(row.officialId)?.locked);
                  const disabled = locked || form.processing;
                  return (
                    <tr key={row.key}>
                      <td
                        {...stylex.props(ui.td, register.cell, register.name)}
                      >
                        <select
                          {...stylex.props(ui.input, register.control)}
                          aria-label={`Official for item ${index + 1}`}
                          disabled={disabled}
                          value={row.officialId ?? ""}
                          onChange={(event) =>
                            updateRow(row.key, {
                              officialId: event.target.value
                                ? Number(event.target.value)
                                : null,
                            })
                          }
                        >
                          <option value="">Choose official</option>
                          {payments.map((payment) => (
                            <option
                              key={payment.id}
                              value={payment.id}
                              disabled={payment.locked}
                            >
                              {payment.payment_number}. {payment.name}
                            </option>
                          ))}
                        </select>
                      </td>
                      <td
                        {...stylex.props(
                          ui.td,
                          register.cell,
                          register.description,
                        )}
                      >
                        <input
                          {...stylex.props(ui.input, register.control)}
                          aria-label={`Item ${index + 1} reason`}
                          value={row.label}
                          maxLength={100}
                          disabled={disabled}
                          onChange={(event) =>
                            updateRow(row.key, { label: event.target.value })
                          }
                        />
                      </td>
                      <td
                        {...stylex.props(ui.td, register.cell, register.amount)}
                      >
                        <input
                          {...stylex.props(
                            ui.input,
                            register.control,
                            register.numeric,
                          )}
                          aria-label={`Item ${index + 1} amount`}
                          value={row.amount}
                          inputMode="decimal"
                          placeholder="0.00"
                          disabled={disabled}
                          onChange={(event) =>
                            updateRow(row.key, { amount: event.target.value })
                          }
                        />
                      </td>
                      <td {...stylex.props(ui.td, register.row)}>
                        {locked ? (
                          "Cheque recorded"
                        ) : (
                          <button
                            type="button"
                            {...stylex.props(ui.textButton)}
                            aria-label={`Remove item ${index + 1}`}
                            disabled={form.processing}
                            onClick={() =>
                              setRows((current) =>
                                current.filter((item) => item.key !== row.key),
                              )
                            }
                          >
                            Remove
                          </button>
                        )}
                      </td>
                    </tr>
                  );
                })}
                {!rows.length && (
                  <tr>
                    <td colSpan={4} {...stylex.props(ui.td)}>
                      No additional items for this year.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
          <div {...stylex.props(ui.tableHeading)}>
            <button
              type="button"
              {...stylex.props(ui.button)}
              disabled={
                form.processing || !payments.some((payment) => !payment.locked)
              }
              onClick={() =>
                setRows((current) => [
                  ...current,
                  {
                    key: Math.max(-1, ...current.map((row) => row.key)) + 1,
                    officialId: null,
                    label: "",
                    amount: "",
                  },
                ])
              }
            >
              Add row
            </button>
            <button
              type="submit"
              {...stylex.props(ui.button, ui.primary)}
              disabled={incomplete || !changes.length || form.processing}
            >
              Save additional items
            </button>
          </div>
        </section>
        {incomplete && (
          <p {...stylex.props(ui.paragraph)}>
            Choose an official and fill in the reason and amount for each item.
          </p>
        )}
      </form>
    </>
  );
}
