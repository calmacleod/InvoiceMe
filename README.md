# InvoiceMe

A private EOTFOA treasurer workspace for Horizon game imports, invoice preparation, PDF/Google Docs generation, payment tracking, and the annual Google Sheets ledger.

## Daily workflow

1. Open **Games & officials → Import Horizon file**. Upload a CSV or XLSX export, match columns, review the totals, then import. Files can contain one row per game, one row per assignment, or separate name/fee columns for each position. All original columns remain available in each game's Source details. ISO dates are accepted automatically; explicitly choose the format of other dates.
2. Choose **Create invoice**. Enter a unique invoice number, recipient, ledger description, dates, and line items. Quantities support three decimal places; rates use exact cents. Optionally select games. Game fees are reference information; linking games does not change invoice prices. The same game can be linked to multiple invoices, with a visible warning.
3. Save the draft, review the preview, and download its PDF if desired. Private notes never appear in the PDF or Google Doc.
4. Choose **Finalize & save to Google**. The app validates the destination and checks for an existing invoice number, freezes the issuer/address/payment details and destination, creates a native Google Doc and PDF, and records the ledger row. After finalization, invoice details cannot be edited. Make corrections using a new invoice number. Private notes remain editable.
5. Record payments against finalized invoices. **Sync to Google** updates the received amount, balance, last payment method, and deposit date. Payment recording is local; syncing is a separate explicit action.

The register contains invoices created in InvoiceMe. Historical invoices already in Drive/Sheets are not automatically migrated. No emails are sent by this app.

## Invoice appearance

The generated invoice follows the supplied EOTFOA ODT: the original logo on the first page, uppercase association letterhead, Calibri-compatible Carlito typography, five-column grey-header table with blank rows, yellow/red total strip, and the original payment/address block. The web preview, PDF, and ODT-to-Google-Docs output use this design. Addresses and payment instructions remain editable in yearly settings.

## Annual settings

The 2026 workspace is seeded with the folder and spreadsheet URLs supplied in the brief. Confirm the mailing address and payment instructions in **Year & settings** before issuing anything. Configure the PDF subfolder there if you want PDFs separated from Docs; otherwise both files use the invoice folder.

**Set up another year** copies organization details but starts with empty Google destinations. Create the new year's folders and spreadsheet in Drive, then paste their URLs into the settings. The year selector switches between existing years.

The master ledger must have these columns in A–I, in order:

| Column | Header |
| --- | --- |
| A | Invoice Number |
| B | Date Sent |
| C | Description |
| D | Contact Name |
| E | Amount Invoiced |
| F | Amount Received |
| G | Amount Owed |
| H | Payment Method |
| I | Date Deposited |

The default first data row is 3, with headers in row 2, matching the existing workbook. The tab name is configurable. Publishing checks the headers, preserves existing records, and refuses ambiguous or already-used invoice numbers. Values are written as raw data, so descriptions and invoice numbers cannot become spreadsheet formulas. Amount Owed is a numeric snapshot from InvoiceMe, updated on each sync. Edit payment records in InvoiceMe to keep the two systems aligned.

## One-time Google connection

Use a Google Cloud project owned by the EOTFOA Workspace, signed in as `treasurer@eotfoa.ca` or with help from its administrator.

1. In [Google Cloud Console](https://console.cloud.google.com/), create/select an **InvoiceMe** project.
2. Enable **Google Drive API** and **Google Sheets API** under **APIs & Services → Library**. The Docs API is not needed: an ODT with its logo embedded is imported as a native Google Doc through Drive.
3. Configure **Google Auth Platform** branding and audience. Use **Internal** if available for the EOTFOA organization. For an External app in Testing, add `treasurer@eotfoa.ca` as a test user; Google expires refresh tokens for this configuration after seven days. For regular use, configure an appropriate production audience with your Workspace administrator. See [Google's OAuth lifecycle documentation](https://developers.google.com/identity/protocols/oauth2).
4. Add the requested data-access scopes: `openid`, `email`, `https://www.googleapis.com/auth/drive`, and `https://www.googleapis.com/auth/spreadsheets`. Full Drive access is needed to find/write the existing manually selected folders and ledger. The application only uses the configured destinations and verifies the connected email against `GOOGLE_ALLOWED_EMAIL`.
5. Create an OAuth client of type **Web application**. Add this exact authorized redirect URI:

   ```text
   https://invoices.callummacleod.ca/google/callback
   ```

   For local development, optionally add `http://localhost:3100/google/callback` and set `APP_URL=http://localhost:3100`.
6. Set `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` in `/opt/invoice-me/.env.production` on the VM. Keep the existing `SECRET_KEY_BASE` and `ADMIN_PASSWORD` values.
7. Apply the new environment:

   ```sh
   cd /opt/invoice-me
   docker compose up -d --force-recreate web
   ```

8. Sign into InvoiceMe, open **Year & settings**, choose **Connect Google account**, and authorize the treasurer account. Check the folder, PDF folder, tab name, and header row before the first publish. The refresh token is encrypted in SQLite using keys derived from `SECRET_KEY_BASE`.

Follow Google's [web-server OAuth guide](https://developers.google.com/identity/protocols/oauth2/web-server) for the consent setup. Revoking access in Google invalidates the connection; reconnect from InvoiceMe. The Disconnect button removes the app's locally stored token; it does not revoke the OAuth grant in your Google account.

## Local development

Ruby 4.0.9 and Bundler are used. No Node build, PostgreSQL, or Redis is needed.

```sh
bundle install
bin/rails db:prepare
bin/rails server -p 3100
```

Open `http://localhost:3100`. Development-only password: `invoice-local`, unless `ADMIN_PASSWORD` is set. Production requires an explicit password and secret key. Sessions expire after 12 hours; login is rate limited.

Run the checks with `bin/ci`: domain/workflow tests, eager-loading check, Brakeman, and production asset compilation. Google writes are tested against a fake API; no live Google changes are performed by tests. A real first-publish verification is still needed after OAuth setup.

## OVH Docker deployment

The app lives at `/opt/invoice-me` on `144.217.240.192` and uses Compose project `invoice-me`, container `invoice-me-web-1`, and volume `invoice_me_storage`. It binds only `127.0.0.1:3100` on the VM. The container joins the existing `kamal` network under alias `invoice-me-web`, and the existing proxy receives a separate service route named `invoice-me-web`. Other application containers, volumes, and routes are not restarted or reconfigured. TLS is handled by the existing proxy.

Create a `.env.production` from `.env.example` for a new installation. Generate a long random password and `SECRET_KEY_BASE`; keep both out of Git. Existing credentials are in the ignored local `.env.production` and the VM's matching file. Never regenerate the secret for an existing database: it is required to decrypt Google tokens.

```sh
cd /opt/invoice-me
docker compose build
docker compose up -d
docker compose exec -T web bin/rails db:seed
docker exec kamal-proxy kamal-proxy deploy invoice-me-web \
  --target invoice-me-web:3000 \
  --host invoices.callummacleod.ca \
  --tls --health-check-path /up --target-timeout 180s
```

The hostname's A record must point to `144.217.240.192` before TLS provisioning. `/up` is public; all application records require login. Google publishing can take longer than a normal web request, so this service route has its own 180-second target timeout.

For updates, copy source files to the same directory and run `docker compose build && docker compose up -d`. This may briefly restart only InvoiceMe. The named volume retains the database. Do not run `docker compose down -v` against a live installation.

View logs using `docker compose logs --tail 100 web`. Retry a failed Google sync from its invoice page after fixing the reported issue. The app records completed file IDs, tags uploads for recovery after lost responses, persists pending ledger row numbers, and serializes Google publications with a cross-process file lock. It never automatically sends an invoice to its recipient. If a failure locks an invoice with incorrect destination settings, inspect it before changing records directly; finalized destinations deliberately remain fixed.

## Backups and recovery

Run `bin/backup` from `/opt/invoice-me`. It uses SQLite's `.backup` command rather than copying an active database file, then copies the consistent snapshot to `backups/` with mode 0600. Keep encrypted copies off the VM, together with a separate secure backup of `.env.production`. This repository includes the backup command; an off-server backup schedule is not configured automatically.

To restore, stop only InvoiceMe (`docker compose stop web`), back up the current volume, restore the snapshot as `production.sqlite3` in `invoice_me_storage` with owner UID/GID 1000, remove stale WAL/SHM files only while stopped, and start the app again. Preserve the matching `SECRET_KEY_BASE`. Verify the restored records before retrying Google publications.

## Horizon integration

This version imports downloaded CSV/XLSX files. It does not scrape the signed-in website and does not assume access to Horizon's Developer API. Export the complete filtered schedule/payroll report yourself and use the upload/review workflow. CSV layouts vary; explicit mapping and separate position-name/fee pairs are supported. API synchronization can be added once EOTFOA's API access and the actual API contract are available.
