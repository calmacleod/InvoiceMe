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
  payment_number: number | null;
  game_count: number;
  official_name: string;
  horizon_user_id: string | null;
  status: "Needs review" | "Reviewed" | "Cheque recorded" | "Deposited";
  cheque_number: string | null;
  deposited_on: string | null;
  adjustments: { label: string; amount_cents: number }[];
};

export type PaymentSortColumn =
  | (typeof moneyColumns)[number]["field"]
  | "official_name"
  | "game_count"
  | "cheque_number"
  | "deposited_on"
  | "status";

export type PaymentSort = {
  column: PaymentSortColumn | null;
  direction: "asc" | "desc";
};

const statusColumn = { field: "status", label: "Status" } as const;
const breakdownEndColumns = [
  { field: "cheque_number", label: "Cheque" },
  { field: "deposited_on", label: "Deposited" },
  statusColumn,
] as const;

export default function EarningsRegister({
  payments,
  sort,
  onSort,
  filtered,
  breakdown,
  headingId,
  totalsLabel,
  emptyMessage,
}: {
  payments: PaymentSummary[];
  sort: PaymentSort;
  onSort: (column: PaymentSortColumn) => void;
  filtered: boolean;
  breakdown: boolean;
  headingId: string;
  totalsLabel: string;
  emptyMessage?: string;
}) {
  const columns = breakdown
    ? moneyColumns
    : moneyColumns.filter((column) => column.field === "net_cents");
  const endColumns = breakdown
    ? breakdownEndColumns
    : [{ ...statusColumn, label: "Payment" }];
  const direction = (column: PaymentSortColumn) =>
    sort.column === column
      ? sort.direction === "asc"
        ? "ascending"
        : "descending"
      : undefined;
  const heading = (column: PaymentSortColumn, label: string) => (
    <button
      type="button"
      {...stylex.props(ui.nativeButton, overview.sortButton)}
      onClick={() => onSort(column)}
    >
      {label}{" "}
      <span aria-hidden="true">
        {sort.column === column ? (sort.direction === "asc" ? "↑" : "↓") : "↕"}
      </span>
    </button>
  );
  return (
    <div
      {...stylex.props(ui.tableScroll, register.scroll, overview.scroll)}
      role="region"
      aria-labelledby={headingId}
      tabIndex={0}
    >
      <table
        {...stylex.props(
          ui.table,
          register.table,
          breakdown && overview.breakdownTable,
        )}
      >
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
              aria-sort={direction("official_name")}
            >
              {heading("official_name", "Official")}
            </th>
            <th
              {...stylex.props(ui.th, ui.numeric, overview.heading)}
              scope="col"
              aria-sort={direction("game_count")}
            >
              {heading("game_count", "Total games")}
            </th>
            {columns.map((column) => (
              <th
                key={column.field}
                {...stylex.props(
                  ui.th,
                  ui.numeric,
                  overview.heading,
                  breakdown && overview.moneyWidth,
                  "divider" in column && breakdown && overview.divider,
                  column.field === "net_cents" && overview.net,
                )}
                scope="col"
                aria-sort={direction(column.field)}
                title={"description" in column ? column.description : undefined}
              >
                {heading(column.field, column.label)}
              </th>
            ))}
            {endColumns.map(({ field, label }) => (
              <th
                key={field}
                {...stylex.props(ui.th, overview.heading)}
                scope="col"
                aria-sort={direction(field)}
              >
                {heading(field, label)}
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
                {(payment.payment_number !== null ||
                  !payment.horizon_user_id) && (
                  <small {...stylex.props(ui.small, overview.paymentNumber)}>
                    {payment.payment_number === null
                      ? ""
                      : `#${payment.payment_number}`}
                    {!payment.horizon_user_id &&
                      (payment.payment_number === null
                        ? "Manual entry"
                        : " · Manual entry")}
                  </small>
                )}
              </th>
              <td {...stylex.props(ui.td, ui.numeric, overview.cell)}>
                {payment.game_count}
              </td>
              {columns.map((column) => {
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
              {breakdown && (
                <>
                  <td {...stylex.props(ui.td, overview.cell, ui.nowrap)}>
                    {payment.cheque_number || "—"}
                  </td>
                  <td {...stylex.props(ui.td, overview.cell, ui.nowrap)}>
                    {date(payment.deposited_on) || "—"}
                  </td>
                </>
              )}
              <td {...stylex.props(ui.td, overview.cell)}>
                <span
                  {...stylex.props(
                    ui.badge,
                    Boolean(payment.deposited_on) && ui.badgePaid,
                  )}
                >
                  {payment.status}
                </span>
                {!breakdown &&
                  (payment.cheque_number || payment.deposited_on) && (
                    <small {...stylex.props(ui.small)}>
                      {[
                        payment.cheque_number &&
                          `Cheque ${payment.cheque_number}`,
                        date(payment.deposited_on),
                      ]
                        .filter(Boolean)
                        .join(" · ")}
                    </small>
                  )}
              </td>
            </tr>
          ))}
          {!payments.length && (
            <tr>
              <td
                {...stylex.props(ui.td, ui.muted)}
                colSpan={2 + columns.length + endColumns.length}
              >
                {emptyMessage}
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
              {filtered ? "Search totals" : totalsLabel}
            </th>
            <td {...stylex.props(ui.td, overview.cell, overview.total)} />
            {columns.map((column) => (
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
              colSpan={endColumns.length}
            />
          </tr>
        </tfoot>
      </table>
    </div>
  );
}
