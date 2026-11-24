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
