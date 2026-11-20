import { Head, useForm } from "@inertiajs/react";
import * as stylex from "@stylexjs/stylex";
import Link from "../../components/AppLink";
import { Errors, Field, Heading, Section } from "../../components/UI";
import { money } from "../../lib/format";
import { ui } from "../../styles/ui.stylex";

type Selection = { id: number; lock_version: number };
type Payment = Selection & {
  name: string;
  locked: boolean;
  amounts: Record<string, number>;
};

export default function BulkEdit({
  year,
  fields,
  payments,
}: {
  year: number;
  fields: { key: string; label: string }[];
  payments: Payment[];
}) {
  const form = useForm<{
    bulk: { amounts: Record<string, string>; payments: Selection[] };
  }>({
    bulk: { amounts: {}, payments: [] },
  });
  const selected = new Set(
    form.data.bulk.payments.map((payment) => payment.id),
  );
  const editable = payments.filter((payment) => !payment.locked);
  const setSelection = (payments: Selection[]) =>
    form.setData("bulk", { ...form.data.bulk, payments });
  const selectionFor = ({ id, lock_version }: Payment): Selection => ({
    id,
    lock_version,
  });
  const hasAmounts = Object.values(form.data.bulk.amounts).some(
    (value) => value.trim() !== "",
  );
  return (
    <>
      <Head title="Bulk edit official payments" />
      <Link {...stylex.props(ui.link)} href="/official_payments">
        ← Officials payments
      </Link>
      <Heading title="Bulk edit amounts">{year} earnings</Heading>
      <Errors errors={form.errors} />
      <form
        onSubmit={(event) => {
          event.preventDefault();
          form.patch("/official_payments/bulk_update", {
            onSuccess: () => form.reset(),
          });
        }}
      >
        <Section
          title="Amounts to set"
          hint="Enter a new amount for each field you want to replace. Leave other fields blank. Enter 0 to clear an amount. Changes return the payment to Needs review."
        >
          <div {...stylex.props(ui.formGrid)}>
            {fields.map(({ key, label }) => (
              <Field
                key={key}
                name={`bulk-${key}`}
                label={label}
                type="number"
                min="0"
                step="0.01"
                value={form.data.bulk.amounts[key] ?? ""}
                onChange={(value) =>
                  form.setData("bulk", {
                    ...form.data.bulk,
                    amounts: { ...form.data.bulk.amounts, [key]: value },
                  })
                }
              />
            ))}
          </div>
        </Section>
        <section {...stylex.props(ui.card, ui.tableCard)}>
          <div {...stylex.props(ui.tableHeading)}>
            <h2 {...stylex.props(ui.h2)}>Select officials</h2>
            <button
              type="button"
              {...stylex.props(ui.button)}
              disabled={!editable.length}
              onClick={() =>
                setSelection(
                  selected.size === editable.length
                    ? []
                    : editable.map(selectionFor),
                )
              }
            >
              {selected.size > 0 && selected.size === editable.length
                ? "Clear selection"
                : "Select all editable"}
            </button>
          </div>
          <div {...stylex.props(ui.tableScroll)}>
            <table {...stylex.props(ui.table)}>
              <thead>
                <tr>
                  <th scope="col" {...stylex.props(ui.th)}>
                    Select
                  </th>
                  <th scope="col" {...stylex.props(ui.th)}>
                    Official
                  </th>
                  {fields.map(({ key, label }) => (
                    <th
                      key={key}
                      scope="col"
                      {...stylex.props(ui.th, ui.numeric)}
                    >
                      {label}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {payments.map((payment) => (
                  <tr key={payment.id}>
                    <td {...stylex.props(ui.td)}>
                      <input
                        type="checkbox"
                        {...stylex.props(ui.checkbox)}
                        aria-label={`Select ${payment.name}`}
                        disabled={payment.locked}
                        checked={selected.has(payment.id)}
                        onChange={(event) =>
                          setSelection(
                            event.target.checked
                              ? [
                                  ...form.data.bulk.payments,
                                  selectionFor(payment),
                                ]
                              : form.data.bulk.payments.filter(
                                  (entry) => entry.id !== payment.id,
                                ),
                          )
                        }
                      />
                    </td>
                    <th scope="row" {...stylex.props(ui.td)}>
                      {payment.name}
                      {payment.locked && (
                        <small {...stylex.props(ui.small)}>
                          Cheque recorded
                        </small>
                      )}
                    </th>
                    {fields.map(({ key }) => (
                      <td key={key} {...stylex.props(ui.td, ui.numeric)}>
                        {money(payment.amounts[key])}
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
        <div {...stylex.props(ui.formActions)}>
          <button
            {...stylex.props(ui.button, ui.primary)}
            disabled={!selected.size || !hasAmounts || form.processing}
          >
            Apply to {selected.size} selected
          </button>
        </div>
      </form>
    </>
  );
}
