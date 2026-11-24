import * as stylex from "@stylexjs/stylex";
import Link from "../../components/AppLink";
import { date, money } from "../../lib/format";
import { ui } from "../../styles/ui.stylex";
import { overview, register } from "./register.stylex";

const moneyColumns = [
  { field: "game_fees_cents", label: "Game fees incl. adj." },
  {
    field: "game_fee_adjustment_cents",
    label: "Game fee adj.",
    description: "Included in game fees",
  },
  { field: "travel_ot_cents", label: "Travel/OT incl. adj." },
  {
    field: "travel_ot_adjustment_cents",
    label: "Travel/OT adj.",
    description: "Included in travel/OT",
  },
  { field: "evaluations_cents", label: "Evaluations" },
  { field: "prepayment_refund_cents", label: "Prepayment refund" },
  { field: "other_cents", label: "Other" },
  { field: "additional_items_cents", label: "Additional items" },
  { field: "association_fee_cents", label: "Association fee", divider: true },
  { field: "registration_cents", label: "OFOA registration" },
  { field: "banquet_cents", label: "Banquet" },
  { field: "next_year_prepayment_cents", label: "Next year’s prepayment" },
  { field: "net_cents", label: "Net earnings", divider: true },
] as const satisfies ReadonlyArray<{
  field: string;
  label: string;
  description?: string;
  divider?: boolean;
}>;

export type PaymentSummary = Record<
  (typeof moneyColumns)[number]["field"],
  number
> & {
  id: number;
  payment_number: number;
  official_name: string;
  horizon_user_id: string | null;
  status: "Needs review" | "Reviewed" | "Cheque recorded" | "Deposited";
  cheque_number: string | null;
  deposited_on: string | null;
  adjustments: { label: string; amount_cents: number }[];
};

export default function EarningsRegister({
  payments,
  filtered,
}: {
  payments: PaymentSummary[];
  filtered: boolean;
}) {
  return (
    <div
      {...stylex.props(ui.tableScroll, register.scroll, overview.scroll)}
      role="region"
      aria-labelledby="earnings-register-heading"
      tabIndex={0}
    >
      <table {...stylex.props(ui.table, register.table)}>
        <thead {...stylex.props(overview.header)}>
          <tr>
            <th
              {...stylex.props(
                ui.th,
                overview.heading,
                overview.official,
                overview.officialHeading,
              )}
              scope="col"
            >
              Official
            </th>
            {moneyColumns.map((column) => (
              <th
                key={column.field}
                {...stylex.props(
                  ui.th,
                  ui.numeric,
                  overview.heading,
                  "divider" in column && overview.divider,
                  column.field === "net_cents" && overview.net,
                )}
                scope="col"
                title={"description" in column ? column.description : undefined}
              >
                {column.label}
              </th>
            ))}
            {["Cheque", "Deposited", "Status"].map((label) => (
              <th
                key={label}
                {...stylex.props(ui.th, overview.heading)}
                scope="col"
              >
                {label}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {payments.map((payment) => (
            <tr {...stylex.props(ui.row)} key={payment.id}>
              <th
                {...stylex.props(ui.td, overview.cell, overview.official)}
                scope="row"
              >
                <Link
                  {...stylex.props(ui.link, ui.strong)}
                  href={`/official_payments/${payment.id}/edit`}
                >
                  {payment.official_name}
                </Link>
                <small {...stylex.props(ui.small, overview.paymentNumber)}>
                  #{payment.payment_number}
                  {!payment.horizon_user_id && " · Manual entry"}
                </small>
              </th>
              {moneyColumns.map((column) => {
                const cents = payment[column.field];
                const additional =
                  column.field === "additional_items_cents" &&
                  payment.adjustments.length > 0;
                const hasAmount =
                  cents !== 0 || additional || column.field === "net_cents";
                return (
                  <td
                    key={column.field}
                    {...stylex.props(
                      ui.td,
                      ui.numeric,
                      overview.cell,
                      additional && overview.additional,
                      "divider" in column && overview.divider,
                      column.field === "net_cents" && overview.net,
                    )}
                  >
                    <span
                      {...stylex.props(ui.nowrap, !hasAmount && overview.zero)}
                    >
                      {hasAmount ? money(cents) : "—"}
                    </span>
                    {additional && (
                      <ul {...stylex.props(overview.items)}>
                        {payment.adjustments.map((item, index) => (
                          <li key={index} {...stylex.props(overview.item)}>
                            <span {...stylex.props(overview.itemLabel)}>
                              {item.label}
                            </span>
                            <span {...stylex.props(ui.nowrap)}>
                              {money(item.amount_cents)}
                            </span>
                          </li>
                        ))}
                      </ul>
                    )}
                  </td>
                );
              })}
              <td {...stylex.props(ui.td, overview.cell, ui.nowrap)}>
                {payment.cheque_number || "—"}
              </td>
              <td {...stylex.props(ui.td, overview.cell, ui.nowrap)}>
                {date(payment.deposited_on) || "—"}
              </td>
              <td {...stylex.props(ui.td, overview.cell, ui.nowrap)}>
                <span
                  {...stylex.props(
                    ui.badge,
                    Boolean(payment.deposited_on) && ui.badgePaid,
                  )}
                >
                  {payment.status}
                </span>
              </td>
            </tr>
          ))}
          {!payments.length && (
            <tr>
              <td
                {...stylex.props(ui.td, ui.muted)}
                colSpan={moneyColumns.length + 4}
              >
                {filtered
                  ? "No officials match this search."
                  : "Pull from Horizon to start the register, or add an official below."}
              </td>
            </tr>
          )}
        </tbody>
        <tfoot {...stylex.props(overview.footer)}>
          <tr>
            <th
              {...stylex.props(
                ui.td,
                overview.cell,
                overview.official,
                overview.total,
              )}
              scope="row"
            >
              {filtered ? "Search totals" : "Season totals"}
            </th>
            {moneyColumns.map((column) => (
              <td
                key={column.field}
                {...stylex.props(
                  ui.td,
                  ui.numeric,
                  ui.nowrap,
                  overview.cell,
                  overview.total,
                  "divider" in column && overview.divider,
                  column.field === "net_cents" && overview.netTotal,
                )}
              >
                {money(
                  payments.reduce(
                    (sum, payment) => sum + payment[column.field],
                    0,
                  ),
                )}
              </td>
            ))}
            <td
              {...stylex.props(ui.td, overview.cell, overview.total)}
              colSpan={3}
            />
          </tr>
        </tfoot>
      </table>
    </div>
  );
}
