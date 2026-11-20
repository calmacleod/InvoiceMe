import { Head, router, useForm } from "@inertiajs/react";
import * as stylex from "@stylexjs/stylex";
import { useEffect, useState } from "react";
import Link from "../../components/AppLink";
import { Errors, Field, Heading, Stat } from "../../components/UI";
import { date, money } from "../../lib/format";
import { ui } from "../../styles/ui.stylex";

export type PaymentSummary = {
  id: number;
  payment_number: number;
  official_name: string;
  horizon_user_id: string | null;
  status: "Needs review" | "Reviewed" | "Cheque recorded" | "Deposited";
  game_fees_cents: number;
  travel_ot_cents: number;
  association_fee_cents: number;
  net_cents: number;
  cheque_number: string | null;
  deposited_on: string | null;
};

type Import = {
  status: "queued" | "running" | "completed" | "failed";
  error: string | null;
  organization_name: string | null;
  official_count: number | null;
  excluded_games: string[];
  changed_cheques: number[];
  updated_at: string;
};

export default function Index({
  year,
  payments,
  totals,
  last_import,
  connections,
  can_import,
  google_connected,
}: {
  year: number;
  payments: PaymentSummary[];
  totals: { net_cents: number; needs_review: number; deposited: number };
  last_import: Import | null;
  connections: { id: number; organization_name: string | null }[];
  can_import: boolean;
  google_connected: boolean;
}) {
  const pull = useForm({
    horizon_connection_id:
      connections.length === 1 ? String(connections[0].id) : "",
  });
  const adding = useForm({ official_payment: { official_name: "" } });
  const exportForm = useForm({});
  const [query, setQuery] = useState("");
  const busy =
    last_import?.status === "queued" || last_import?.status === "running";
  const shown = payments.filter((payment) =>
    payment.official_name
      .toLocaleLowerCase()
      .includes(query.trim().toLocaleLowerCase()),
  );
  useEffect(() => {
    if (!busy) return;
    const timer = window.setInterval(() => {
      if (!document.hidden)
        router.reload({ only: ["payments", "totals", "last_import"] });
    }, 3000);
    return () => window.clearInterval(timer);
  }, [busy]);
  return (
    <>
      <Head title="Officials payments" />
      <Heading
        title="Officials payments"
        actions={
          <form
            onSubmit={(event) => {
              event.preventDefault();
              pull.post("/official_payments/import");
            }}
          >
            {connections.length > 1 && (
              <label {...stylex.props(ui.label)}>
                Horizon organization
                <select
                  {...stylex.props(ui.input)}
                  value={pull.data.horizon_connection_id}
                  onChange={(event) =>
                    pull.setData("horizon_connection_id", event.target.value)
                  }
                >
                  <option value="">Choose an organization</option>
                  {connections.map((connection) => (
                    <option key={connection.id} value={connection.id}>
                      {connection.organization_name ||
                        `Horizon connection ${connection.id}`}
                    </option>
                  ))}
                </select>
              </label>
            )}
            <button
              {...stylex.props(ui.button, ui.primary)}
              disabled={
                !can_import ||
                !pull.data.horizon_connection_id ||
                busy ||
                pull.processing
              }
            >
              Pull from Horizon
            </button>
          </form>
        }
      >
        Review {year} earnings, record cheques and deposits, and export
        individual statements.
      </Heading>
      {!can_import && (
        <p {...stylex.props(ui.flash)}>
          {year > new Date().getFullYear()
            ? "Horizon imports open once the selected year starts."
            : "Connect Horizon in Year & settings to pull earnings."}
        </p>
      )}
      {busy && (
        <p {...stylex.props(ui.flash)} role="status">
          Reading the Horizon schedule…
        </p>
      )}
      {last_import?.status === "failed" && (
        <p {...stylex.props(ui.flash, ui.alert)} role="alert">
          {last_import.error}
        </p>
      )}
      {last_import?.status === "completed" && (
        <div {...stylex.props(ui.flash)} role="status">
          <p {...stylex.props(ui.paragraph)}>
            Horizon refreshed {last_import.official_count} officials
            {last_import.organization_name &&
              ` for ${last_import.organization_name}`}{" "}
            on {date(last_import.updated_at.slice(0, 10))}.
          </p>
          {!!last_import.excluded_games.length && (
            <p {...stylex.props(ui.paragraph)}>
              Check these games in Horizon. The import excluded them because
              their payment or cancellation status needs review.{" "}
              {last_import.excluded_games.join(", ")}
            </p>
          )}
          {!!last_import.changed_cheques.length && (
            <p {...stylex.props(ui.paragraph)}>
              Horizon changed after cheques were recorded for{" "}
              {payments
                .filter((payment) =>
                  last_import.changed_cheques.includes(payment.id),
                )
                .map((payment) => payment.official_name)
                .join(", ")}
              . The register retained their recorded earnings.
            </p>
          )}
        </div>
      )}
      <div {...stylex.props(ui.stats)}>
        <Stat label="Net earnings" value={money(totals.net_cents)} dark />
        <Stat label="Needs review" value={totals.needs_review}>
          {payments.length} officials
        </Stat>
        <Stat label="Cheques deposited" value={totals.deposited} />
      </div>
      <section {...stylex.props(ui.card, ui.tableCard)}>
        <div {...stylex.props(ui.tableHeading)}>
          <h2 {...stylex.props(ui.h2)}>Earnings register</h2>
          {payments.length > 0 && (
            <Link
              {...stylex.props(ui.link, ui.button)}
              href="/official_payments/bulk_edit"
            >
              Enter payment amounts
            </Link>
          )}
          {payments.length > 0 && (
            <Link
              {...stylex.props(ui.link, ui.button)}
              href="/official_payments/adjustments"
            >
              Additional items
            </Link>
          )}
          {payments.length > 0 && google_connected && (
            <button
              type="button"
              {...stylex.props(ui.button)}
              disabled={busy || exportForm.processing}
              onClick={() => exportForm.post("/official_payments/export_sheet")}
            >
              Export final Google Sheet
            </button>
          )}
          <input
            {...stylex.props(ui.input)}
            type="search"
            aria-label="Search officials"
            placeholder="Search officials"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
          />
        </div>
        <div {...stylex.props(ui.tableScroll)}>
          <table {...stylex.props(ui.table)}>
            <thead>
              <tr>
                <th {...stylex.props(ui.th)} scope="col">
                  Payment #
                </th>
                <th {...stylex.props(ui.th)} scope="col">
                  Official
                </th>
                <th {...stylex.props(ui.th, ui.numeric)} scope="col">
                  Game fees
                </th>
                <th {...stylex.props(ui.th, ui.numeric)} scope="col">
                  Travel/OT
                </th>
                <th {...stylex.props(ui.th, ui.numeric)} scope="col">
                  Net earnings
                </th>
                <th {...stylex.props(ui.th)} scope="col">
                  Cheque
                </th>
                <th {...stylex.props(ui.th)} scope="col">
                  Deposited
                </th>
                <th {...stylex.props(ui.th)} scope="col">
                  Status
                </th>
              </tr>
            </thead>
            <tbody>
              {shown.map((payment) => (
                <tr key={payment.id}>
                  <td {...stylex.props(ui.td)}>{payment.payment_number}</td>
                  <td {...stylex.props(ui.td)}>
                    <Link
                      {...stylex.props(ui.link)}
                      href={`/official_payments/${payment.id}/edit`}
                    >
                      {payment.official_name}
                    </Link>
                    {!payment.horizon_user_id && (
                      <small {...stylex.props(ui.small, ui.muted)}>
                        Manual entry
                      </small>
                    )}
                  </td>
                  <td {...stylex.props(ui.td, ui.numeric)}>
                    {money(payment.game_fees_cents)}
                  </td>
                  <td {...stylex.props(ui.td, ui.numeric)}>
                    {money(payment.travel_ot_cents)}
                  </td>
                  <td {...stylex.props(ui.td, ui.numeric, ui.strong)}>
                    {money(payment.net_cents)}
                  </td>
                  <td {...stylex.props(ui.td)}>
                    {payment.cheque_number || "—"}
                  </td>
                  <td {...stylex.props(ui.td)}>
                    {date(payment.deposited_on) || "—"}
                  </td>
                  <td {...stylex.props(ui.td)}>
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
              {!shown.length && (
                <tr>
                  <td {...stylex.props(ui.td, ui.muted)} colSpan={8}>
                    {payments.length
                      ? "No officials match this search."
                      : "Pull from Horizon to start the register, or add an official below."}
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </section>
      <section {...stylex.props(ui.card)}>
        <h2 {...stylex.props(ui.h2)}>Add an official manually</h2>
        <p {...stylex.props(ui.paragraph)}>
          Use this for a payment to an official with no Horizon earnings row.
        </p>
        <Errors errors={adding.errors} />
        <form
          onSubmit={(event) => {
            event.preventDefault();
            adding.post("/official_payments");
          }}
        >
          <div {...stylex.props(ui.formGrid)}>
            <Field
              label="Name (Last, First)"
              name="official_name"
              maxLength={100}
              required
              value={adding.data.official_payment.official_name}
              onChange={(name) =>
                adding.setData("official_payment", { official_name: name })
              }
            />
          </div>
          <div {...stylex.props(ui.formActions)}>
            <button {...stylex.props(ui.button)} disabled={adding.processing}>
              Add official
            </button>
          </div>
        </form>
      </section>
    </>
  );
}
