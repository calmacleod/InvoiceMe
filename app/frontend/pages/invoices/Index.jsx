import { Head, Link, usePage } from "@inertiajs/react";
import { Badge, Heading, Search, Stat, date, money } from "../../components/UI";

export default function Index({ invoices, total_count, query, totals }) {
  const { current_season: season } = usePage().props;
  return (
    <>
      <Head title="Invoices" />
      <Heading
        eyebrow="YOUR SEASON, IN ORDER"
        title="Invoices."
        actions={
          <Link href="/invoices/new" className="button primary">
            + Create invoice
          </Link>
        }
      >
        A clear view of what's drafted, invoiced, and paid.
      </Heading>
      <div className="stats">
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
      <section className="card table-card">
        <div className="table-heading">
          <div>
            <h2>
              Invoice register <span className="count">{total_count}</span>
            </h2>
            <p>Your records for the {season.year} season.</p>
          </div>
          <Search url="/" query={query} label="Search invoices" />
        </div>
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>Invoice</th>
                <th>Recipient / description</th>
                <th>Date</th>
                <th>Status</th>
                <th className="numeric">Amount</th>
                <th className="numeric">Balance</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {invoices.map((invoice) => (
                <tr key={invoice.id}>
                  <td>
                    <Link
                      href={`/invoices/${invoice.id}`}
                      className="invoice-link"
                    >
                      {invoice.number}
                    </Link>
                  </td>
                  <td>
                    <strong>{invoice.recipient}</strong>
                    <small>{invoice.description}</small>
                  </td>
                  <td className="nowrap">{date(invoice.issued_on)}</td>
                  <td>
                    <Badge status={invoice.status} />
                  </td>
                  <td className="numeric">{money(invoice.total_cents)}</td>
                  <td className="numeric">{money(invoice.owed_cents)}</td>
                  <td>
                    <Link
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
          <div className="empty">
            <span className="empty-icon">▤</span>
            <h2>
              {query ? "No matching invoices" : "Your next invoice starts here"}
            </h2>
            <p>
              Import your games or create an invoice with your own line items.
            </p>
            <div className="actions">
              <Link href="/games/new" className="button">
                Import Horizon games
              </Link>
              <Link href="/invoices/new" className="button primary">
                + Create invoice
              </Link>
            </div>
          </div>
        )}
        <div className="table-bottom">
          <span>Amounts in CAD</span>
          <span>Drafts stay private until you publish to Google.</span>
        </div>
      </section>
      <div className="workflow-card">
        <div className="workflow-number">01 — 03</div>
        <div>
          <h3>From game day to paid.</h3>
          <p>
            Import from Horizon, build your invoice, then save to Drive and your
            master ledger.
          </p>
        </div>
        <Link href="/games/new" className="small-link">
          Import games →
        </Link>
      </div>
    </>
  );
}
