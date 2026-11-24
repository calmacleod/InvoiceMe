import { Head, useForm } from "@inertiajs/react";
import * as stylex from "@stylexjs/stylex";
import { useRef, useState } from "react";
import type { ClipboardEvent, KeyboardEvent } from "react";
import Link from "../../components/AppLink";
import { Errors, Heading } from "../../components/UI";
import { ui } from "../../styles/ui.stylex";
import { register } from "./register.stylex";

type Payment = {
  id: number;
  name: string;
  payment_number: number | null;
  lock_version: number;
  locked: boolean;
  amounts: Record<string, number>;
};
type Update = {
  id: number;
  lock_version: number;
  amounts: Record<string, string>;
};
type Cell = { payment: Payment; key: string; value: string };
const display = (cents: number) => (cents ? (cents / 100).toFixed(2) : "");

export default function BulkEdit({
  year,
  fields,
  payments,
}: {
  year: number;
  fields: { key: string; label: string }[];
  payments: Payment[];
}) {
  const form = useForm<{ payments: Update[] }>({ payments: [] });
  const grid = useRef<HTMLTableElement>(null);
  const [updates, setUpdates] = useState<Record<number, Update>>({});
  const [pasteError, setPasteError] = useState("");
  const dirty = Object.values(updates);

  function editCells(cells: Cell[]) {
    setPasteError("");
    setUpdates((previous) => {
      const next = { ...previous };
      for (const { payment, key, value } of cells) {
        const update = next[payment.id];
        const amounts = { ...update?.amounts };
        if (value === display(payment.amounts[key])) delete amounts[key];
        else amounts[key] = value;

        if (Object.keys(amounts).length) {
          next[payment.id] = {
            id: payment.id,
            lock_version: update?.lock_version ?? payment.lock_version,
            amounts,
          };
        } else {
          delete next[payment.id];
        }
      }
      return next;
    });
  }

  function paste(event: ClipboardEvent, row: number, column: number) {
    const text = event.clipboardData.getData("text/plain");
    if (!/[\t\r\n]/.test(text)) return;

    event.preventDefault();
    const values = text
      .replace(/\r\n?/g, "\n")
      .replace(/\n$/, "")
      .split("\n")
      .map((line) => line.split("\t"));
    const cells: Cell[] = [];
    for (const [offset, valuesInRow] of values.entries()) {
      const payment = payments[row + offset];
      if (
        !payment ||
        payment.locked ||
        column + valuesInRow.length > fields.length
      ) {
        setPasteError(
          "The pasted range must fit in editable cells. A recorded cheque locks its row.",
        );
        return;
      }
      valuesInRow.forEach((value, index) =>
        cells.push({
          payment,
          key: fields[column + index].key,
          value: value.trim(),
        }),
      );
    }
    editCells(cells);
  }

  function move(
    event: KeyboardEvent<HTMLInputElement>,
    row: number,
    column: number,
  ) {
    if (!["Enter", "ArrowUp", "ArrowDown"].includes(event.key)) return;
    event.preventDefault();
    const step =
      event.key === "ArrowUp" || (event.key === "Enter" && event.shiftKey)
        ? -1
        : 1;
    let next = row + step;
    while (payments[next]?.locked) next += step;
    const target = grid.current?.querySelector<HTMLInputElement>(
      `[data-row="${next}"][data-column="${column}"]:not(:disabled)`,
    );
    target?.focus();
    target?.select();
  }

  return (
    <>
      <Head title="Enter payment amounts" />
      <Link {...stylex.props(ui.link)} href="/official_payments">
        ← Officials payments
      </Link>
      <Heading title="Payment amounts">
        Enter {year} amounts by official or paste a range from a spreadsheet.
        Clearing a cell sets it to zero.
      </Heading>
      <Errors errors={form.errors} />
      {pasteError && (
        <p role="alert" {...stylex.props(ui.flash, ui.alert)}>
          {pasteError}
        </p>
      )}
      <form
        onSubmit={(event) => {
          event.preventDefault();
          form.transform(() => ({ payments: dirty }));
          form.patch("/official_payments/bulk_update", {
            onSuccess: () => setUpdates({}),
          });
        }}
      >
        <section {...stylex.props(ui.card, ui.tableCard)}>
          <div {...stylex.props(ui.tableScroll, register.scroll)}>
            <table ref={grid} {...stylex.props(ui.table, register.table)}>
              <thead>
                <tr>
                  <th
                    scope="col"
                    {...stylex.props(
                      ui.th,
                      register.official,
                      register.header,
                      register.officialHeader,
                    )}
                  >
                    Payment / Official
                  </th>
                  {fields.map(({ key, label }) => (
                    <th
                      key={key}
                      scope="col"
                      {...stylex.props(ui.th, register.header)}
                    >
                      {label}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {payments.map((payment, row) => (
                  <tr {...stylex.props(ui.row)} key={payment.id}>
                    <th
                      scope="row"
                      {...stylex.props(ui.td, register.row, register.official)}
                    >
                      <Link
                        {...stylex.props(ui.link)}
                        href={`/official_payments/${payment.id}/edit`}
                      >
                        {payment.payment_number === null
                          ? payment.name
                          : `${payment.payment_number}. ${payment.name}`}
                      </Link>
                      {payment.locked && (
                        <small {...stylex.props(ui.small)}>
                          Cheque recorded
                        </small>
                      )}
                    </th>
                    {fields.map(({ key, label }, column) => {
                      const value = updates[payment.id]?.amounts[key];
                      return (
                        <td
                          key={key}
                          {...stylex.props(
                            ui.td,
                            register.cell,
                            register.amount,
                          )}
                        >
                          <input
                            {...stylex.props(
                              ui.input,
                              register.control,
                              register.numeric,
                              value !== undefined && register.pending,
                            )}
                            aria-label={`${label} for ${payment.name}`}
                            data-row={row}
                            data-column={column}
                            inputMode="decimal"
                            size={8}
                            placeholder="0.00"
                            value={value ?? display(payment.amounts[key])}
                            disabled={payment.locked || form.processing}
                            onChange={(event) =>
                              editCells([
                                { payment, key, value: event.target.value },
                              ])
                            }
                            onKeyDown={(event) => move(event, row, column)}
                            onPaste={(event) => paste(event, row, column)}
                          />
                        </td>
                      );
                    })}
                  </tr>
                ))}
                {!payments.length && (
                  <tr>
                    <td colSpan={fields.length + 1} {...stylex.props(ui.td)}>
                      Add or import officials to enter amounts.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </section>
        <div {...stylex.props(ui.formActions, ui.sticky)}>
          <button
            type="submit"
            {...stylex.props(ui.button, ui.primary)}
            disabled={!dirty.length || form.processing}
          >
            Save amounts
          </button>
        </div>
      </form>
    </>
  );
}
