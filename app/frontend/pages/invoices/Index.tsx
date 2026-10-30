import Link from "../../components/AppLink";
import type {
  InvoiceSummary,
  InvoiceTotals,
  Pagination,
  DraftMetadata,
} from "../../types";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../../styles/ui.stylex";
import { Head, usePage } from "@inertiajs/react";
import {
  Badge,
  Heading,
  Search,
  Stat,
  PaginationControls,
} from "../../components/UI";
import { date, money } from "../../lib/format";
import { DraftShelf } from "../../components/DraftWorkbench";
export default function Index({
  invoices,
  total_count,
  query,
  totals,
  pagination,
  workbenches,
}: {
  invoices: InvoiceSummary[];
  total_count: number;
  query: string;
  totals: InvoiceTotals;
  pagination: Pagination;
  workbenches: DraftMetadata[];
}) {
  const { current_season: season } = usePage().props;
  if (!season) return null;
  return (
    <>
      <Head title="Invoices" />
      <Heading
        eyebrow="YOUR SEASON, IN ORDER"
        title="Invoices."
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
        A clear view of what's drafted, invoiced, and paid.
      </Heading>
      <div {...stylex.props(ui.stats)}>
        <Stat label="Total invoiced ↗" value={money(totals.invoiced)}>
          {season.year} season
        </Stat>
        <Stat label="Received ✓" value={money(totals.received)}>
          Payments recorded this season
        </Stat>
        <Stat label="Outstanding ◷" value={money(totals.owed)}>
          {totals.outstanding} invoices awaiting payment
        </Stat>
        <Stat label="Work in progress ✎" value={totals.drafts} dark>
          Drafts ready when you are
        </Stat>
      </div>
      <DraftShelf drafts={workbenches} />
      <section {...stylex.props(ui.card, ui.tableCard)}>
        <div {...stylex.props(ui.tableHeading)}>
          <div>
            <h2 {...stylex.props(ui.h2)}>
              Invoice register{" "}
              <span {...stylex.props(ui.count)}>{total_count}</span>
            </h2>
            <p {...stylex.props(ui.paragraph)}>
              Your records for the {season.year} season.
            </p>
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
                <th {...stylex.props(ui.th)}>Invoice</th>
                <th {...stylex.props(ui.th)}>Recipient / description</th>
                <th {...stylex.props(ui.th)}>Date</th>
                <th {...stylex.props(ui.th)}>Status</th>
                <th {...stylex.props(ui.th, ui.numeric)}>Amount</th>
                <th {...stylex.props(ui.th, ui.numeric)}>Balance</th>
                <th {...stylex.props(ui.th)} />
              </tr>
            </thead>
            <tbody>
              {invoices.map((invoice) => (
                <tr key={invoice.id}>
                  <td {...stylex.props(ui.td)}>
                    <Link
                      {...stylex.props(ui.link, ui.invoiceLink)}
                      href={`/invoices/${invoice.id}`}
                    >
                      {invoice.number}
                    </Link>
                  </td>
                  <td {...stylex.props(ui.td)}>
                    <strong {...stylex.props(ui.strong)}>
                      {invoice.recipient}
                    </strong>
                    <small {...stylex.props(ui.small)}>
                      {invoice.description}
                    </small>
                  </td>
                  <td {...stylex.props(ui.td, ui.nowrap)}>
                    {date(invoice.issued_on)}
                  </td>
                  <td {...stylex.props(ui.td)}>
                    <Badge status={invoice.status} />
                  </td>
                  <td {...stylex.props(ui.td, ui.numeric)}>
                    {money(invoice.total_cents)}
                  </td>
                  <td {...stylex.props(ui.td, ui.numeric)}>
                    {money(invoice.owed_cents)}
                  </td>
                  <td {...stylex.props(ui.td)}>
                    <Link
                      {...stylex.props(ui.link)}
                      href={`/invoices/${invoice.id}`}
                      aria-label={`Open ${invoice.number}`}
                    >
                      ↗
                    </Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {!invoices.length && (
          <div {...stylex.props(ui.empty)}>
            <span {...stylex.props(ui.emptyIcon)}>▤</span>
            <h2 {...stylex.props(ui.h2)}>
              {query ? "No matching invoices" : "Your next invoice starts here"}
            </h2>
            <p {...stylex.props(ui.paragraph)}>
              Import your games or create an invoice with your own line items.
            </p>
            <div {...stylex.props(ui.actions, ui.emptyActions)}>
              <Link {...stylex.props(ui.link, ui.button)} href="/games/new">
                Import Horizon games
              </Link>
              <Link
                {...stylex.props(ui.link, ui.button, ui.primary)}
                href="/invoice_drafts"
                method="post"
                as="button"
              >
                + Create invoice
              </Link>
            </div>
          </div>
        )}
        <PaginationControls
          pagination={pagination}
          url="/"
          query={query}
          only={["invoices", "pagination", "query"]}
        />
        <div {...stylex.props(ui.tableBottom)}>
          <span>Amounts in CAD</span>
          <span>Drafts stay private until you publish to Google.</span>
        </div>
      </section>
      <div {...stylex.props(ui.workflowCard)}>
        <div {...stylex.props(ui.workflowNumber)}>01 — 03</div>
        <div>
          <h3 {...stylex.props(ui.h3)}>From game day to paid.</h3>
          <p {...stylex.props(ui.paragraph)}>
            Import from Horizon, build your invoice, then save to Drive and your
            master ledger.
          </p>
        </div>
        <Link
          {...stylex.props(ui.link, ui.smallLink, ui.workflowLink)}
          href="/games/new"
        >
          Import games →
        </Link>
      </div>
    </>
  );
}
