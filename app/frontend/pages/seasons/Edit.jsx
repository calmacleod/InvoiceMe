import { Head, Link, useForm } from "@inertiajs/react";
import { Errors, Field, Heading, Section } from "../../components/UI";

export default function Edit({ season, google }) {
  const form = useForm({
    ...season,
    drive_folder_id: season.drive_folder_id ?? "",
    pdf_folder_id: season.pdf_folder_id ?? "",
    spreadsheet_id: season.spreadsheet_id ?? "",
  });
  const disconnect = useForm({});
  const field = (key, label, props = {}) => (
    <Field
      name={key}
      label={label}
      value={form.data[key]}
      onChange={(value) => form.setData(key, value)}
      {...props}
    />
  );
  const issuerField = (key, label, props = {}) => (
    <Field
      name={`issuer_${key}`}
      label={label}
      value={form.data.issuer[key]}
      onChange={(value) =>
        form.setData("issuer", { ...form.data.issuer, [key]: value })
      }
      {...props}
    />
  );
  function submit(event) {
    event.preventDefault();
    form.transform((data) => ({ season: data }));
    if (season.id) form.patch(`/seasons/${season.id}`);
    else form.post("/seasons");
  }
  return (
    <>
      <Head title="Year & settings" />
      <Heading
        eyebrow="WORKSPACE SETTINGS"
        title={
          season.id ? `${season.year} invoice year` : "Set up another year"
        }
        actions={
          season.id && (
            <div className="actions">
              <a
                href={`/seasons/${season.id}/preview`}
                target="_blank"
                rel="noopener"
                className="button"
              >
                Preview invoice design ↗
              </a>
              <Link href="/seasons/new" className="button">
                + Another year
              </Link>
            </div>
          )
        }
      >
        Update your details here. Finalized invoices retain their original
        information.
      </Heading>
      {season.id && (
        <>
          <div className="card connection">
            <div>
              <h2>Google Drive connection</h2>
              <p>
                {google.email ||
                  "Connect your treasurer account to publish documents and update the ledger."}
              </p>
            </div>
            {google.email ? (
              <button
                className="button"
                disabled={disconnect.processing}
                onClick={() => disconnect.delete("/google/disconnect")}
              >
                Disconnect
              </button>
            ) : (
              <Link
                as="button"
                method="post"
                href="/google/connect"
                className="button primary"
              >
                Connect Google account ↗
              </Link>
            )}
          </div>
          {!google.configured && (
            <div className="flash notice">
              Google OAuth credentials are not configured yet. See the README
              for the one-time server setup.
            </div>
          )}
        </>
      )}
      <form onSubmit={submit} className="settings-form">
        <Errors errors={form.errors} />
        <Section
          step="01"
          title="Year & Google Drive"
          hint="Paste file or folder URLs, or their Google IDs."
        >
          <div className="form-grid">
            {field("year", "Year", {
              type: "number",
              min: 2000,
              max: 2200,
              required: true,
            })}
            {field("sheet_name", "Master spreadsheet tab name", {
              required: true,
            })}
            {field("drive_folder_id", "Invoice folder")}
            {field("pdf_folder_id", "PDF folder (optional)")}
            {field("spreadsheet_id", "Master spreadsheet")}
            {field("ledger_start_row", "First ledger data row", {
              type: "number",
              min: 2,
              required: true,
            })}
          </div>
          <p className="hint">
            The ledger uses columns A–I: invoice number, date, description,
            contact, invoiced, received, owed, payment method, deposited date.
            Existing rows remain in place.
          </p>
        </Section>
        <Section
          step="02"
          title="Organization & payment details"
          hint="These details appear on new invoices. All amounts are in Canadian dollars."
        >
          <div className="form-grid">
            {issuerField("name", "Organization name", { required: true })}
            {issuerField("payable_to", "Cheques payable to", {
              required: true,
            })}
            {issuerField("treasurer", "Treasurer name", { required: true })}
            {issuerField("email", "E-transfer / contact email", {
              type: "email",
              required: true,
            })}
            {issuerField("address", "Mailing address", {
              multiline: true,
              rows: 4,
              required: true,
            })}
            {issuerField("payment_instructions", "Payment instructions", {
              multiline: true,
              rows: 4,
            })}
          </div>
        </Section>
        <div className="form-actions">
          <Link href="/" className="button">
            Back to invoices
          </Link>
          <button className="button primary" disabled={form.processing}>
            Save year settings
          </button>
        </div>
      </form>
    </>
  );
}
