import Link from "../../components/AppLink";
import type {
  InvoiceSummary,
  InvoiceTotals,
  Pagination,
  DraftMetadata,
} from "../../types";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../../styles/ui.stylex";
import { Head, useForm, usePage, usePoll } from "@inertiajs/react";
import { useEffect } from "react";
import {
  Badge,
  Heading,
  Search,
  Stat,
  PaginationControls,
} from "../../components/UI";
import { date, money } from "../../lib/format";
import { DraftShelf } from "../../components/DraftWorkbench";
type PaymentCheck = {
  ready: boolean;
  active: boolean;
  status: "idle" | "queued" | "running" | "succeeded" | "failed";
  imported_count: number;
  review_count: number;
  finished_at: string | null;
  error: string | null;
};

const checkTime = new Intl.DateTimeFormat("en-CA", {
  month: "short",
  day: "numeric",
  hour: "numeric",
  minute: "2-digit",
  timeZone: "America/Toronto",
});

function paymentCheckMessage(check: PaymentCheck) {
  if (check.active) return "Checking the invoice ledger…";
  if (!check.ready)
    return "Connect the treasurer Google account to check payments.";
  if (check.status === "idle") return "InvoiceMe checks the ledger hourly.";
  const result = check.imported_count
    ? `${check.imported_count} ${check.imported_count === 1 ? "payment" : "payments"} recorded.`
    : "No new payments.";
  const review = check.review_count
    ? ` ${check.review_count} ${check.review_count === 1 ? "row needs" : "rows need"} review in the ledger.`
    : "";
  if (check.error)
    return check.imported_count ? `${check.error} ${result}` : check.error;
  const time = check.finished_at
    ? `Checked ${checkTime.format(new Date(check.finished_at))}. `
    : "";
  return `${time}${result}${review}`;
}

export default function Index({
  invoices,
  total_count,
  query,
  totals,
  pagination,
  workbenches,
  payment_check,
}: {
  invoices: InvoiceSummary[];
  total_count: number;
  query: string;
  totals: InvoiceTotals;
  pagination: Pagination;
  workbenches: DraftMetadata[];
  payment_check: PaymentCheck;
}) {
  const { current_season: season } = usePage().props;
  const checkForm = useForm({});
  const { start, stop } = usePoll(
    2500,
    { only: ["payment_check", "invoices", "totals"] },
    { autoStart: false, background: "pause", mode: "rest" },
  );
  useEffect(() => {
    if (payment_check.active) start();
    return stop;
  }, [payment_check.active, start, stop]);

  if (!season) return null;
  const checkQuery = new URLSearchParams({
    season_id: String(season.id),
    page: String(pagination.page),
    per_page: String(pagination.per_page),
  });
  if (query) checkQuery.set("q", query);
  return (
    <>
      <Head title="Invoices" />
      <Heading
        title="Invoices"
        actions={
          <Link
            {...stylex.props(ui.link, ui.button, ui.primary)}
            href="/invoice_drafts"
            method="post"
            as="button"
          >
            + Create invoice
          </Link>
        }
      >
        {season.year} invoice register
      </Heading>
      <div {...stylex.props(ui.stats)}>
        <Stat label="Total invoiced" value={money(totals.invoiced)} />
        <Stat label="Received" value={money(totals.received)} />
        <Stat label="Outstanding" value={money(totals.owed)} dark>
          {totals.outstanding} invoices awaiting payment
        </Stat>
        <Stat label="Drafts" value={totals.drafts} />
      </div>
      <section {...stylex.props(ui.card, ui.connection)}>
        <div>
          <h2 {...stylex.props(ui.h2)}>Google Sheets payments</h2>
          <p
            role={payment_check.error ? "alert" : "status"}
            {...stylex.props(ui.paragraph, !!payment_check.error && ui.danger)}
          >
            {paymentCheckMessage(payment_check)}
          </p>
        </div>
        {payment_check.ready ? (
          <button
            {...stylex.props(ui.nativeButton, ui.button)}
            disabled={payment_check.active || checkForm.processing}
            onClick={() =>
              checkForm.post(`/invoices/check_payments?${checkQuery}`, {
                preserveScroll: true,
              })
            }
          >
            Check for payments
          </button>
        ) : (
          <Link
            {...stylex.props(ui.link, ui.button)}
            href={`/seasons/${season.id}/edit`}
          >
            Year &amp; settings
          </Link>
        )}
      </section>
      <DraftShelf drafts={workbenches} />
      <section {...stylex.props(ui.card, ui.tableCard)}>
        <div {...stylex.props(ui.tableHeading)}>
          <div>
            <h2 {...stylex.props(ui.h2)}>
              Invoice register{" "}
              <span {...stylex.props(ui.count)}>{total_count}</span>
            </h2>
          </div>
          <Search
            url="/"
            query={query}
            label="Search invoices"
            perPage={pagination.per_page}
            only={["invoices", "pagination", "query"]}
          />
        </div>
        <div {...stylex.props(ui.tableScroll)}>
          <table {...stylex.props(ui.table)}>
            <thead>
              <tr>
                <th {...stylex.props(ui.th, ui.desktopOnly)}>Invoice</th>
                <th {...stylex.props(ui.th)}>
                  <span {...stylex.props(ui.desktopOnly)}>
                    Recipient / description
                  </span>
                  <span {...stylex.props(ui.mobileOnly)}>Invoice</span>
                </th>
                <th {...stylex.props(ui.th, ui.desktopOnly)}>Date</th>
                <th {...stylex.props(ui.th)}>Status</th>
                <th {...stylex.props(ui.th, ui.numeric)}>Amount</th>
                <th {...stylex.props(ui.th, ui.numeric, ui.desktopOnly)}>
                  Balance
                </th>
              </tr>
            </thead>
            <tbody>
              {invoices.map((invoice) => (
                <tr {...stylex.props(ui.row)} key={invoice.id}>
                  <td {...stylex.props(ui.td, ui.desktopOnly)}>
                    <Link
                      {...stylex.props(ui.link, ui.invoiceLink)}
                      href={`/invoices/${invoice.id}`}
                    >
                      {invoice.number}
                    </Link>
                  </td>
                  <td {...stylex.props(ui.td, ui.breakText)}>
                    <strong {...stylex.props(ui.strong, ui.desktopOnly)}>
                      {invoice.recipient}
                    </strong>
                    <Link
                      {...stylex.props(ui.link, ui.invoiceLink, ui.mobileOnly)}
                      href={`/invoices/${invoice.id}`}
                    >
                      {invoice.recipient || invoice.number}
                    </Link>
                    {invoice.recipient && (
                      <small {...stylex.props(ui.small, ui.mobileDetail)}>
                        {invoice.number}
                      </small>
                    )}
                    <small {...stylex.props(ui.small)}>
                      {invoice.description}
                    </small>
                    <small {...stylex.props(ui.small, ui.mobileDetail)}>
                      {date(invoice.issued_on)}
                    </small>
                  </td>
                  <td {...stylex.props(ui.td, ui.nowrap, ui.desktopOnly)}>
                    {date(invoice.issued_on)}
                  </td>
                  <td {...stylex.props(ui.td)}>
                    <Badge status={invoice.status} />
                  </td>
                  <td {...stylex.props(ui.td, ui.numeric)}>
                    {money(invoice.total_cents)}
                    {invoice.owed_cents > 0 && (
                      <small
                        {...stylex.props(ui.small, ui.mobileDetail, ui.nowrap)}
                      >
                        {money(invoice.owed_cents)} due
                      </small>
                    )}
                  </td>
                  <td {...stylex.props(ui.td, ui.numeric, ui.desktopOnly)}>
                    {money(invoice.owed_cents)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {!invoices.length && (
          <div {...stylex.props(ui.empty)}>
            <h2 {...stylex.props(ui.h2)}>
              {query ? "No matching invoices" : "No invoices this year"}
            </h2>
            {!query && (
              <div {...stylex.props(ui.actions, ui.emptyActions)}>
                <Link {...stylex.props(ui.link, ui.button)} href="/games/new">
                  Import Horizon games
                </Link>
              </div>
            )}
          </div>
        )}
        <PaginationControls
          pagination={pagination}
          url="/"
          query={query}
          only={["invoices", "pagination", "query"]}
        />
      </section>
    </>
  );
}
