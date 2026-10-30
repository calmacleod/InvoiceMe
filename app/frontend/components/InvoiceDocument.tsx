import type { SavedInvoice } from "../types";
import { usePage } from "@inertiajs/react";

const amount = (cents: number | null, rate = false) =>
  `$${(Number(cents) / 100).toFixed(rate && Number(cents) % 100 === 0 ? 0 : 2)}`;
const lines = (text: string | null | undefined) =>
  String(text ?? "")
    .split("\n")
    .map((line, index) => (
      <span key={index}>
        {line}
        <br />
      </span>
    ));
export default function InvoiceDocument({
  invoice,
}: {
  invoice: SavedInvoice;
}) {
  const { logo_url } = usePage().props;
  const issuer = invoice.issuer;
  const title = invoice.recipient.includes(String(invoice.year))
    ? invoice.recipient
    : `${invoice.recipient} ${invoice.year}`;
  const longDate = (value: string) =>
    new Intl.DateTimeFormat("en-CA", {
      month: "long",
      day: "numeric",
      year: "numeric",
    }).format(new Date(`${value}T12:00:00`));
  return (
    <div className="document">
      <header className="doc-letterhead">
        <img
          src={logo_url}
          alt="Eastern Ontario Tackle Football Officials logo"
          className="doc-logo"
        />
        <strong>{issuer.name.toUpperCase()}</strong>
      </header>
      <p className="doc-heading">
        FINAL INVOICE FOR <strong>{title}</strong>
      </p>
      <div className="doc-metadata">
        <p>Invoice date: {longDate(invoice.issued_on)}</p>
        <p>Invoice number: {invoice.number}</p>
        {invoice.due_on && <p>Due date: {longDate(invoice.due_on)}</p>}
        {invoice.recipient_address && <p>{lines(invoice.recipient_address)}</p>}
        <p>
          <strong>ATTENTION: {invoice.contact || invoice.recipient}</strong>
        </p>
      </div>
      <table className="doc-items">
        <colgroup>
          {["number", "description", "quantity", "rate", "charge"].map(
            (name) => (
              <col key={name} className={`doc-item-${name}`} />
            ),
          )}
        </colgroup>
        <thead>
          <tr>
            {["Item", "Description", "Quantity", "Rate", "Charge"].map(
              (label) => (
                <th key={label}>{label}</th>
              ),
            )}
          </tr>
        </thead>
        <tbody>
          {invoice.line_items.map((item, i) => (
            <tr key={item.id}>
              <td>{i + 1}</td>
              <td>{item.description}</td>
              <td>{item.amount_only ? "" : Number(item.quantity)}</td>
              <td>{item.amount_only ? "" : amount(item.rate_cents, true)}</td>
              <td>{amount(item.total_cents)}</td>
            </tr>
          ))}
          {Array.from(
            { length: Math.max(5 - invoice.line_items.length, 0) },
            (_, i) => (
              <tr className="doc-blank" key={`blank-${i}`}>
                <td>&nbsp;</td>
                <td />
                <td />
                <td />
                <td />
              </tr>
            ),
          )}
          <tr className="doc-table-total">
            <td colSpan={4}>
              <strong>Total</strong>
            </td>
            <td>{amount(invoice.total_cents)}</td>
          </tr>
        </tbody>
      </table>
      <div className="doc-total">
        <span>TOTAL PAYABLE</span>
        <strong>{amount(invoice.total_cents)}</strong>
      </div>
      <div className="doc-payment">
        <p>
          {String(issuer.payment_instructions ?? "")
            .split(/(check|cheque|e-transfer)/i)
            .map((part, i) =>
              /^(check|cheque|e-transfer)$/i.test(part) ? (
                <strong key={i}>
                  <em>
                    <u>{part}</u>
                  </em>
                </strong>
              ) : (
                part
              ),
            )}
        </p>
        <p>
          If paying by <strong>e-transfer</strong>, please email{" "}
          <a href={`mailto:${issuer.email}`}>{issuer.email}</a>
        </p>
        <div className="doc-mailing">
          <p>
            If paying by <strong>check</strong>, please make it payable to:
          </p>
          <p>
            <strong>{issuer.payable_to}</strong>
          </p>
          <p>And mail to</p>
          <p>
            <strong>
              {issuer.treasurer}
              <br />
              {lines(issuer.address)}
            </strong>
          </p>
        </div>
      </div>
      {invoice.public_notes && (
        <div className="doc-public-notes">
          <p>{lines(invoice.public_notes)}</p>
        </div>
      )}
      <div className="doc-signoff">
        <p>Thank you.</p>
        <p>
          {issuer.treasurer}
          <br />
          Treasurer, EOTFOA
          <br />
          <a href={`mailto:${issuer.email}`}>{issuer.email}</a>
        </p>
      </div>
    </div>
  );
}
