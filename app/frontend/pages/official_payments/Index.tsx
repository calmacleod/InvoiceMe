import { Head, router, useForm } from "@inertiajs/react";
import * as stylex from "@stylexjs/stylex";
import { useEffect, useState } from "react";
import Link from "../../components/AppLink";
import { Errors, Field, Heading } from "../../components/UI";
import { date, money } from "../../lib/format";
import { ui } from "../../styles/ui.stylex";

import EarningsRegister, { type PaymentSummary } from "./EarningsRegister";
import { overview } from "./register.stylex";

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
  horizon_configured,
  google_connected,
}: {
  year: number;
  payments: PaymentSummary[];
  totals: { net_cents: number; needs_review: number; deposited: number };
  last_import: Import | null;
  connections: { id: number; organization_name: string | null }[];
  can_import: boolean;
  horizon_configured: boolean;
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
  const search = query.trim().toLocaleLowerCase();
  const shown = payments.filter((payment) =>
    payment.official_name.toLocaleLowerCase().includes(search),
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
          {!horizon_configured
            ? "This InvoiceMe deployment is missing its Horizon credentials."
            : connections.length === 0
              ? "Connect Horizon in Year & settings to pull earnings."
              : "Horizon imports open once the selected year starts."}
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
      <dl {...stylex.props(overview.summary)}>
        <div {...stylex.props(overview.stat)}>
          <dt {...stylex.props(ui.muted)}>Season net earnings</dt>
          <dd {...stylex.props(overview.statValue)}>
            {money(totals.net_cents)}
          </dd>
        </div>
        <div {...stylex.props(overview.stat)}>
          <dt {...stylex.props(ui.muted)}>Needs review</dt>
          <dd {...stylex.props(overview.statValue)}>
            {totals.needs_review} of {payments.length}
          </dd>
        </div>
        <div {...stylex.props(overview.stat)}>
          <dt {...stylex.props(ui.muted)}>Cheques deposited</dt>
          <dd {...stylex.props(overview.statValue)}>{totals.deposited}</dd>
        </div>
      </dl>
      <section {...stylex.props(ui.card, ui.tableCard)}>
        <div {...stylex.props(ui.tableHeading, overview.toolbar)}>
          <h2
            id="earnings-register-heading"
            {...stylex.props(ui.h2, overview.registerTitle)}
          >
            Earnings register
          </h2>
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
            {...stylex.props(ui.input, ui.searchInput)}
            type="search"
            aria-label="Search officials"
            placeholder="Search officials"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
          />
        </div>
        <EarningsRegister payments={shown} filtered={Boolean(search)} />
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
