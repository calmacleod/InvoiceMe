import Link from "../../components/AppLink";
import type { SavedInvoice } from "../../types";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../../styles/ui.stylex";
import { Head, useForm, usePage } from "@inertiajs/react";
import { Badge, Errors, Field, Heading } from "../../components/UI";
import { money } from "../../lib/format";
import InvoiceDocument from "../../components/InvoiceDocument";
export default function Show({ invoice }: { invoice: SavedInvoice }) {
  const { today } = usePage().props;
  const notes = useForm({
    private_notes: invoice.private_notes ?? "",
  });
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
          <div {...stylex.props(ui.actions)}>
            <Badge status={invoice.status} />
            {!invoice.finalized_at && (
              <Link {...stylex.props(ui.link, ui.button)} href={`${url}/edit`}>
                Edit draft
              </Link>
            )}
            <a
              {...stylex.props(ui.link, ui.button)}
              href={`${url}.pdf`}
              target="_blank"
              rel="noopener"
            >
              Download PDF ↗
            </a>
          </div>
        }
      >
        {invoice.description}
      </Heading>
      {invoice.publish_error && (
        <div {...stylex.props(ui.flash, ui.alert)}>
          <strong {...stylex.props(ui.strong)}>
            Google sync needs attention.
          </strong>{" "}
          {invoice.publish_error} Your invoice and completed export steps are
          retained. Retry after resolving the problem.
        </div>
      )}
      <div {...stylex.props(ui.editorLayout)}>
        <section {...stylex.props(ui.card, ui.invoicePaper)}>
          <InvoiceDocument invoice={invoice} />
        </section>
        <aside {...stylex.props(ui.editorAside)}>
          <section {...stylex.props(ui.card)}>
            <h2 {...stylex.props(ui.h2)}>
              {invoice.finalized_at ? "Google records" : "Ready to publish?"}
            </h2>
            <p {...stylex.props(ui.paragraph, ui.hint)}>
              {invoice.finalized_at
                ? "Sync safely resumes completed steps and updates the ledger."
                : "Publishing finalizes the invoice, saves a Google Doc and PDF, and records it in your master spreadsheet."}
            </p>
            <button
              {...stylex.props(ui.nativeButton, ui.button, ui.primary, ui.full)}
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
              <p {...stylex.props(ui.paragraph)}>
                <a
                  {...stylex.props(ui.link)}
                  href={`https://docs.google.com/document/d/${invoice.google_doc_id}/edit`}
                  target="_blank"
                  rel="noopener"
                >
                  Open Google Doc ↗
                </a>
              </p>
            )}
            {invoice.google_pdf_id && (
              <p {...stylex.props(ui.paragraph)}>
                <a
                  {...stylex.props(ui.link)}
                  href={`https://drive.google.com/file/d/${invoice.google_pdf_id}/view`}
                  target="_blank"
                  rel="noopener"
                >
                  Open Drive PDF ↗
                </a>
              </p>
            )}
            {invoice.ledger_row && (
              <p {...stylex.props(ui.paragraph, ui.hint)}>
                Master ledger row {invoice.ledger_row}
              </p>
            )}
          </section>
          {invoice.finalized_at && (
            <section {...stylex.props(ui.card)}>
              <h2 {...stylex.props(ui.h2)}>Payments</h2>
              <div {...stylex.props(ui.balance)}>
                <span>Received</span>
                <strong {...stylex.props(ui.strong)}>
                  {money(invoice.received_cents)}
                </strong>
                <span>Outstanding</span>
                <strong {...stylex.props(ui.strong)}>
                  {money(invoice.owed_cents)}
                </strong>
              </div>
              {invoice.payments.map((item) => (
                <p {...stylex.props(ui.paragraph, ui.hint)} key={item.id}>
                  {item.received_on} · {item.method} ·{" "}
                  {money(item.amount_cents)}
                </p>
              ))}
              {invoice.owed_cents > 0 && (
                <form
                  {...stylex.props(ui.formStack)}
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
                  <label {...stylex.props(ui.label)} htmlFor="payment_method">
                    Payment method
                  </label>
                  <select
                    {...stylex.props(ui.input)}
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
                  <button
                    {...stylex.props(ui.nativeButton, ui.button, ui.full)}
                    disabled={payment.processing}
                  >
                    Record payment
                  </button>
                </form>
              )}
            </section>
          )}
          <section {...stylex.props(ui.card)}>
            <h2 {...stylex.props(ui.h2)}>Private notes</h2>
            <form
              {...stylex.props(ui.formStack)}
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
              <button
                {...stylex.props(ui.nativeButton, ui.button, ui.full)}
                disabled={notes.processing}
              >
                Save notes
              </button>
            </form>
            <p {...stylex.props(ui.paragraph, ui.hint)}>
              For your records. Not included in the document or PDF.
            </p>
          </section>
          {!!invoice.games.length && (
            <section {...stylex.props(ui.card)}>
              <h2 {...stylex.props(ui.h2)}>Linked games</h2>
              {invoice.games.map((game) => (
                <p {...stylex.props(ui.paragraph)} key={game.id}>
                  <strong {...stylex.props(ui.strong)}>
                    {game.code} · #{game.external_id}
                  </strong>
                  <small {...stylex.props(ui.small)}>
                    {game.date} · {game.matchup}
                  </small>
                </p>
              ))}
            </section>
          )}
          {!invoice.finalized_at && (
            <button
              {...stylex.props(ui.nativeButton, ui.textButton, ui.danger)}
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
