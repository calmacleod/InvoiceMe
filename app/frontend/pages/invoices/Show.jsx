import { Head, Link, useForm, usePage } from "@inertiajs/react";
import { Badge, Errors, Field, Heading, money } from "../../components/UI";
import InvoiceDocument from "../../components/InvoiceDocument";

export default function Show({ invoice }) {
  const { today } = usePage().props;
  const notes = useForm({ private_notes: invoice.private_notes ?? "" });
  const payment = useForm({
    amount: "",
    received_on: today,
    payment_method: "Cheque",
    notes: "",
  });
  const publish = useForm({});
  const deletion = useForm({});
  const url = `/invoices/${invoice.id}`;
  return (
    <>
      <Head title={invoice.number} />
      <Heading
        title={invoice.number}
        actions={
          <div className="actions">
            <Badge status={invoice.status} />
            {!invoice.finalized_at && (
              <Link href={`${url}/edit`} className="button">
                Edit draft
              </Link>
            )}
            <a
              href={`${url}.pdf`}
              target="_blank"
              rel="noopener"
              className="button"
            >
              Download PDF ↗
            </a>
          </div>
        }
      >
        {invoice.description}
      </Heading>
      {invoice.publish_error && (
        <div className="flash alert">
          <strong>Google sync needs attention.</strong> {invoice.publish_error}{" "}
          Your invoice and completed export steps are retained. Retry after
          resolving the problem.
        </div>
      )}
      <div className="editor-layout">
        <section className="card invoice-paper">
          <InvoiceDocument invoice={invoice} />
        </section>
        <aside className="editor-aside">
          <section className="card">
            <h2>
              {invoice.finalized_at ? "Google records" : "Ready to publish?"}
            </h2>
            <p className="hint">
              {invoice.finalized_at
                ? "Sync safely resumes completed steps and updates the ledger."
                : "Publishing finalizes the invoice, saves a Google Doc and PDF, and records it in your master spreadsheet."}
            </p>
            <button
              className="button primary full"
              disabled={publish.processing}
              onClick={() => {
                if (
                  invoice.finalized_at ||
                  window.confirm(
                    "Finalize this invoice and save it to Google Drive and the master spreadsheet? Finalized details cannot be edited.",
                  )
                )
                  publish.post(`${url}/publish`);
              }}
            >
              {publish.processing
                ? "Saving…"
                : invoice.finalized_at
                  ? "Sync to Google ↗"
                  : "Finalize & save to Google ↗"}
            </button>
            {invoice.google_doc_id && (
              <p>
                <a
                  href={`https://docs.google.com/document/d/${invoice.google_doc_id}/edit`}
                  target="_blank"
                  rel="noopener"
                >
                  Open Google Doc ↗
                </a>
              </p>
            )}
            {invoice.google_pdf_id && (
              <p>
                <a
                  href={`https://drive.google.com/file/d/${invoice.google_pdf_id}/view`}
                  target="_blank"
                  rel="noopener"
                >
                  Open Drive PDF ↗
                </a>
              </p>
            )}
            {invoice.ledger_row && (
              <p className="hint">Master ledger row {invoice.ledger_row}</p>
            )}
          </section>
          {invoice.finalized_at && (
            <section className="card">
              <h2>Payments</h2>
              <div className="balance">
                <span>Received</span>
                <strong>{money(invoice.received_cents)}</strong>
                <span>Outstanding</span>
                <strong>{money(invoice.owed_cents)}</strong>
              </div>
              {invoice.payments.map((item) => (
                <p key={item.id} className="hint">
                  {item.received_on} · {item.method} ·{" "}
                  {money(item.amount_cents)}
                </p>
              ))}
              {invoice.owed_cents > 0 && (
                <form
                  onSubmit={(event) => {
                    event.preventDefault();
                    payment.post(`${url}/payment`, {
                      onSuccess: () => payment.reset("amount", "notes"),
                    });
                  }}
                >
                  <Errors errors={payment.errors} />
                  <Field
                    name="amount"
                    label="Amount received (CAD)"
                    type="number"
                    value={payment.data.amount}
                    onChange={(value) => payment.setData("amount", value)}
                    min="0.01"
                    step="0.01"
                    max={invoice.owed_cents / 100}
                    required
                  />
                  <Field
                    name="received_on"
                    label="Deposit date"
                    type="date"
                    value={payment.data.received_on}
                    onChange={(value) => payment.setData("received_on", value)}
                    required
                  />
                  <label htmlFor="payment_method">Payment method</label>
                  <select
                    id="payment_method"
                    value={payment.data.payment_method}
                    onChange={(event) =>
                      payment.setData("payment_method", event.target.value)
                    }
                  >
                    {[
                      "Cheque",
                      "E-Deposit",
                      "Direct Deposit",
                      "Cash",
                      "Other",
                    ].map((method) => (
                      <option key={method}>{method}</option>
                    ))}
                  </select>
                  <Field
                    name="payment_notes"
                    label="Payment notes"
                    multiline
                    rows={2}
                    value={payment.data.notes}
                    onChange={(value) => payment.setData("notes", value)}
                  />
                  <button className="button full" disabled={payment.processing}>
                    Record payment
                  </button>
                </form>
              )}
            </section>
          )}
          <section className="card">
            <h2>Private notes</h2>
            <form
              onSubmit={(event) => {
                event.preventDefault();
                notes.patch(`${url}/notes`);
              }}
            >
              <Field
                name="private_notes"
                label="Private notes"
                multiline
                rows={4}
                value={notes.data.private_notes}
                onChange={(value) => notes.setData("private_notes", value)}
              />
              <button className="button full" disabled={notes.processing}>
                Save notes
              </button>
            </form>
            <p className="hint">
              For your records. Not included in the document or PDF.
            </p>
          </section>
          {!!invoice.games.length && (
            <section className="card">
              <h2>Linked games</h2>
              {invoice.games.map((game) => (
                <p key={game.id}>
                  <strong>
                    {game.code} · #{game.external_id}
                  </strong>
                  <small>
                    {game.date} · {game.matchup}
                  </small>
                </p>
              ))}
            </section>
          )}
          {!invoice.finalized_at && (
            <button
              className="text-button danger"
              disabled={deletion.processing}
              onClick={() => {
                if (window.confirm("Delete this draft?")) deletion.delete(url);
              }}
            >
              Delete draft
            </button>
          )}
        </aside>
      </div>
    </>
  );
}
