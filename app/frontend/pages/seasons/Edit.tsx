import type { FormEvent } from "react";
import type { SeasonSettings, SeasonForm, Issuer } from "../../types";
import type { FieldOptions } from "../../components/UI";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../../styles/ui.stylex";
import { Head, Link, useForm } from "@inertiajs/react";
import { Errors, Field, Heading, Section } from "../../components/UI";
export default function Edit({
  season,
  google,
}: {
  season: SeasonSettings;
  google: { configured: boolean; email: string | null };
}) {
  const form = useForm<SeasonForm>({
    year: String(season.year),
    ledger_start_row: String(season.ledger_start_row),
    issuer: season.issuer,
    sheet_name: season.sheet_name,
    drive_folder_id: season.drive_folder_id ?? "",
    pdf_folder_id: season.pdf_folder_id ?? "",
    spreadsheet_id: season.spreadsheet_id ?? "",
  });
  const disconnect = useForm({});
  const field = (
    key: Exclude<keyof SeasonForm, "issuer">,
    label: string,
    props: FieldOptions = {},
  ) => (
    <Field
      name={key}
      label={label}
      value={form.data[key]}
      onChange={(value) => form.setData(key, value)}
      {...props}
    />
  );
  const issuerField = (
    key: keyof Issuer,
    label: string,
    props: FieldOptions = {},
  ) => (
    <Field
      name={`issuer_${key}`}
      label={label}
      value={form.data.issuer[key]}
      onChange={(value) =>
        form.setData("issuer", {
          ...form.data.issuer,
          [key]: value,
        })
      }
      {...props}
    />
  );
  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    form.transform((data) => ({
      season: data,
    }));
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
            <div {...stylex.props(ui.actions)}>
              <a
                {...stylex.props(ui.link, ui.button)}
                href={`/seasons/${season.id}/preview`}
                target="_blank"
                rel="noopener"
              >
                Preview invoice design ↗
              </a>
              <Link {...stylex.props(ui.link, ui.button)} href="/seasons/new">
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
          <div {...stylex.props(ui.card, ui.connection)}>
            <div>
              <h2 {...stylex.props(ui.h2)}>Google Drive connection</h2>
              <p {...stylex.props(ui.paragraph)}>
                {google.email ||
                  "Connect your treasurer account to publish documents and update the ledger."}
              </p>
            </div>
            {google.email ? (
              <button
                {...stylex.props(ui.nativeButton, ui.button)}
                disabled={disconnect.processing}
                onClick={() => disconnect.delete("/google/disconnect")}
              >
                Disconnect
              </button>
            ) : (
              <Link
                {...stylex.props(ui.link, ui.button, ui.primary)}
                as="button"
                method="post"
                href="/google/connect"
              >
                Connect Google account ↗
              </Link>
            )}
          </div>
          {!google.configured && (
            <div {...stylex.props(ui.flash)}>
              Google OAuth credentials are not configured yet. See the README
              for the one-time server setup.
            </div>
          )}
        </>
      )}
      <form onSubmit={submit}>
        <Errors errors={form.errors} />
        <Section
          step="01"
          title="Year & Google Drive"
          hint="Paste file or folder URLs, or their Google IDs."
        >
          <div {...stylex.props(ui.formGrid)}>
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
          <p {...stylex.props(ui.paragraph, ui.hint)}>
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
          <div {...stylex.props(ui.formGrid)}>
            {issuerField("name", "Organization name", {
              required: true,
            })}
            {issuerField("payable_to", "Cheques payable to", {
              required: true,
            })}
            {issuerField("treasurer", "Treasurer name", {
              required: true,
            })}
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
        <div {...stylex.props(ui.formActions)}>
          <Link {...stylex.props(ui.link, ui.button)} href="/">
            Back to invoices
          </Link>
          <button
            {...stylex.props(ui.nativeButton, ui.button, ui.primary)}
            disabled={form.processing}
          >
            Save year settings
          </button>
        </div>
      </form>
    </>
  );
}
