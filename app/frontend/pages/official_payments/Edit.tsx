import { Head, useForm } from "@inertiajs/react";
import * as stylex from "@stylexjs/stylex";
import Link from "../../components/AppLink";
import { Errors, Field, Heading, Section, Stat } from "../../components/UI";
import { date, money } from "../../lib/format";
import { ui } from "../../styles/ui.stylex";
import type { PaymentSummary } from "./Index";

const earnings = [
  ["game_fee_adjustment", "Game fee adjustment"],
  ["travel_ot_adjustment", "Travel/OT adjustment"],
  ["evaluations", "Evaluations"],
  ["prepayment_refund", "Prepayment refund"],
  ["other", "Other (credit or deduction)"],
] as const;
const deductions = [
  ["registration", "OFOA registration"],
  ["banquet", "Banquet"],
  ["next_year_prepayment", "Next year’s prepayment"],
] as const;
type AmountField = (typeof earnings | typeof deductions)[number][0];
type Assignment = {
  id: string;
  game: string;
  date: string;
  position: string;
  accepted: string;
  fee_cents: number;
  travel_ot_cents: number;
  deductions_cents: number;
};
type Payment = PaymentSummary & {
  lock_version: number;
  cheque_delivery: string | null;
  imported_game_fees_cents: number;
  imported_travel_ot_cents: number;
  horizon_deductions_cents: number;
  amounts: Record<AmountField, number>;
  assignments: Assignment[];
};
type Props = { payment: Payment; year: number; google_connected: boolean };

export default function Edit(props: Props) {
  return (
    <PaymentEditor
      key={`${props.payment.id}-${props.payment.lock_version}`}
      {...props}
    />
  );
}

function PaymentEditor({ payment, year, google_connected }: Props) {
  const base = `/official_payments/${payment.id}`;
  const reviewed = payment.status !== "Needs review";
  const locked = Boolean(payment.cheque_number);
  const initialAmounts = Object.fromEntries(
    Object.entries(payment.amounts).map(([key, cents]) => [
      key,
      (cents / 100).toFixed(2),
    ]),
  ) as Record<AmountField, string>;
  const form = useForm({
    official_payment: {
      ...initialAmounts,
      lock_version: payment.lock_version,
      reviewed,
      cheque_number: payment.cheque_number ?? "",
      deposited_on: payment.deposited_on ?? "",
      cheque_delivery: payment.cheque_delivery ?? "",
    },
  });
  const google = useForm({});
  const data = form.data.official_payment;
  const amountField = ([key, label]: readonly [AmountField, string]) => (
    <Field
      key={key}
      label={label}
      name={key}
      type="number"
      step="0.01"
      value={data[key]}
      disabled={locked}
      onChange={(value) =>
        form.setData("official_payment", {
          ...data,
          [key]: value,
          reviewed: false,
        })
      }
    />
  );
  return (
    <>
      <Head title={`${payment.official_name} · Officials payments`} />
      <Link {...stylex.props(ui.link)} href="/official_payments">
        ← Officials payments
      </Link>
      <Heading title={payment.official_name}>
        {year} earnings · {payment.status}
      </Heading>
      <div {...stylex.props(ui.stats)}>
        <Stat label="Net earnings" value={money(payment.net_cents)} dark />
        <Stat label="Game fees" value={money(payment.game_fees_cents)} />
        <Stat
          label="Association fee"
          value={money(payment.association_fee_cents)}
        />
      </div>
      <Errors errors={form.errors} />
      <form
        onSubmit={(event) => {
          event.preventDefault();
          form.patch(base);
        }}
      >
        <Section title="Earnings and adjustments">
          <p {...stylex.props(ui.paragraph)}>
            Horizon game fees {money(payment.imported_game_fees_cents)} ·
            Horizon travel, per diem, tolls and other game fees{" "}
            {money(payment.imported_travel_ot_cents)}
          </p>
          {locked && (
            <p {...stylex.props(ui.paragraph)}>
              Clear the recorded cheque, deposit date and delivery, then save to
              edit earnings.
            </p>
          )}
          <div {...stylex.props(ui.formGrid)}>{earnings.map(amountField)}</div>
        </Section>
        <Section title="Deductions">
          <p {...stylex.props(ui.paragraph)}>
            Association fee is 8% of the first $2,500 of game fees and 4% of the
            next $2,000.
            {payment.horizon_user_id &&
              ` Horizon reports ${money(payment.horizon_deductions_cents)} in assignment deductions for comparison.`}
          </p>
          <div {...stylex.props(ui.formGrid)}>
            {deductions.map(amountField)}
          </div>
        </Section>
        <Section title="Review and cheque">
          <label {...stylex.props(ui.label)}>
            <input
              {...stylex.props(ui.checkbox)}
              type="checkbox"
              checked={data.reviewed}
              disabled={locked}
              onChange={(event) =>
                form.setData("official_payment", {
                  ...data,
                  reviewed: event.target.checked,
                })
              }
            />{" "}
            Earnings reconciled with the Horizon payroll report and any manual
            adjustments
          </label>
          <div {...stylex.props(ui.formGrid)}>
            <Field
              label="Cheque number"
              name="cheque_number"
              maxLength={40}
              value={data.cheque_number}
              onChange={(cheque_number) =>
                form.setData("official_payment", { ...data, cheque_number })
              }
            />
            <Field
              label="Date deposited"
              name="deposited_on"
              type="date"
              value={data.deposited_on}
              onChange={(deposited_on) =>
                form.setData("official_payment", { ...data, deposited_on })
              }
            />
            <Field
              label="Cheque delivery"
              name="cheque_delivery"
              maxLength={100}
              value={data.cheque_delivery}
              onChange={(cheque_delivery) =>
                form.setData("official_payment", { ...data, cheque_delivery })
              }
            />
          </div>
          <div {...stylex.props(ui.formActions)}>
            <button
              {...stylex.props(ui.button, ui.primary)}
              disabled={form.processing}
            >
              Save payment
            </button>
          </div>
        </Section>
      </form>
      {reviewed && !form.isDirty && (
        <Section title="Earnings statement">
          <div {...stylex.props(ui.formActions)}>
            <a {...stylex.props(ui.link, ui.button)} href={`${base}/pdf`}>
              Download PDF
            </a>
            <a {...stylex.props(ui.link, ui.button)} href={`${base}/odt`}>
              Download editable document
            </a>
            {google_connected && (
              <button
                {...stylex.props(ui.button, ui.primary)}
                disabled={google.processing}
                onClick={() => google.post(`${base}/google_doc`)}
              >
                Generate Google Doc
              </button>
            )}
          </div>
        </Section>
      )}
      {payment.horizon_user_id && (
        <section {...stylex.props(ui.card, ui.tableCard)}>
          <div {...stylex.props(ui.tableHeading)}>
            <h2 {...stylex.props(ui.h2)}>Horizon assignments</h2>
          </div>
          <div {...stylex.props(ui.tableScroll)}>
            <table {...stylex.props(ui.table)}>
              <thead>
                <tr>
                  <th {...stylex.props(ui.th)} scope="col">
                    Game
                  </th>
                  <th {...stylex.props(ui.th)} scope="col">
                    Date
                  </th>
                  <th {...stylex.props(ui.th)} scope="col">
                    Position
                  </th>
                  <th {...stylex.props(ui.th)} scope="col">
                    Accepted
                  </th>
                  <th {...stylex.props(ui.th, ui.numeric)} scope="col">
                    Game fee
                  </th>
                  <th {...stylex.props(ui.th, ui.numeric)} scope="col">
                    Travel/OT
                  </th>
                  <th {...stylex.props(ui.th, ui.numeric)} scope="col">
                    Horizon deductions
                  </th>
                </tr>
              </thead>
              <tbody>
                {payment.assignments.map((assignment) => (
                  <tr key={assignment.id}>
                    <td {...stylex.props(ui.td)}>{assignment.game}</td>
                    <td {...stylex.props(ui.td)}>{date(assignment.date)}</td>
                    <td {...stylex.props(ui.td)}>{assignment.position}</td>
                    <td {...stylex.props(ui.td)}>
                      {assignment.accepted || "—"}
                    </td>
                    <td {...stylex.props(ui.td, ui.numeric)}>
                      {money(assignment.fee_cents)}
                    </td>
                    <td {...stylex.props(ui.td, ui.numeric)}>
                      {money(assignment.travel_ot_cents)}
                    </td>
                    <td {...stylex.props(ui.td, ui.numeric)}>
                      {money(assignment.deductions_cents)}
                    </td>
                  </tr>
                ))}
                {!payment.assignments.length && (
                  <tr>
                    <td {...stylex.props(ui.td)} colSpan={7}>
                      No qualifying assignments in the latest import.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </section>
      )}
    </>
  );
}
