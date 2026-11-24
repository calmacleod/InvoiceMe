# InvoiceMe

A private EOTFOA treasurer workspace for Horizon game imports, invoice preparation, PDF/Google Docs generation, payment tracking, and the annual Google Sheets ledger.

## Daily workflow

1. Open **Games & officials → Import Horizon file**. Upload a CSV or XLSX export, match columns, review the totals, then import. Files can contain one row per game, one row per assignment, or separate name/fee columns for each position. All original columns remain available in each game's Source details. ISO dates are accepted automatically; explicitly choose the format of other dates.
2. Choose **Create invoice**. Enter only the invoice number's **Identifying info**, recipient, ledger description, dates, and line items. **Save & preview** adds the workspace year and next sequence automatically (for example, `2026_05_ExampleClub`). It reads the configured master spreadsheet, checks saved local invoices, and retains the ledger's leading-zero padding. Google must be connected and the ledger accessible before a new number can be assigned; autosaves remain available if Google is unavailable. Saved drafts retain their assigned year/sequence, deleted drafts do not free their assigned numbers, and each year has its own sequence. Only the identifying info can change before the invoice is first finalized; existing invoices keep their numbers. Quantities support three decimal places; rates use exact cents. Optionally select games. Game fees are reference information; linking games does not change invoice prices. The same game can be linked to multiple invoices, with a visible warning.
3. Save the draft, review the preview, and download its PDF if desired. Private notes never appear in the PDF or Google Doc.
4. Choose **Finalize & save to Google**. The app queues a background export and shows its progress on the invoice page. You can leave the page and return later. The job validates the destination and checks for an existing invoice number, freezes the issuer/address/payment details and destination, creates a native Google Doc and PDF, and records the ledger row. For an invoice you have not sent yet, choose **Return to draft**, make your changes, then finalize again. The existing Google Doc, PDF, and ledger entry are updated, preserving their links and the original Google destination. Until then, Google retains the previous version. The invoice number stays fixed, and previously finalized invoices cannot be deleted. Reopening is blocked while an export is active or after a payment has been recorded. Private notes remain editable.
5. Record payments against finalized invoices. **Sync to Google** updates the received amount, balance, last payment method, and deposit date. If you mark a published invoice fully paid in Google Sheets, InvoiceMe checks hourly and records any outstanding balance using the ledger’s payment method and deposit date. Use **Check for payments** on the Invoices screen to run the check for the selected year immediately.

The register contains invoices created in InvoiceMe. Historical invoices already in Drive/Sheets are not automatically migrated. Invoice emails are not sent by this app. Password resets use Action Mailer.

Google exports run through Active Job and the existing Solid Queue worker in production. The invoice page polls progress every two seconds while an export is active, pauses polling in a hidden tab, and refreshes the invoice when the export finishes. Status, completed file IDs, and the pending ledger row are retained in the database. Repeated clicks reuse the active export. Invoice edits, deletion, and payment recording wait until the export finishes; private notes remain editable.

Ledger exports fill the first available invoice row inside the configured native Sheets table. Template zero amounts and balance formulas do not make an otherwise empty row occupied. Partial entries and notes remain protected, and full tables require another row inside the table before exporting. Sync preserves the balance formula, date formats, dropdowns, and table formatting. Existing InvoiceMe entries below the table move into an available table row in one atomic values-only update; their saved Docs and PDFs are reused.

Temporary Google server errors, rate limits, and interrupted connections retry up to five total attempts, with increasing delays of approximately 10 seconds, 30 seconds, two minutes, and five minutes. Each attempt rechecks for previously created Drive files and reuses saved file IDs and the ledger row. Permission, authorization, and destination errors stop immediately with guidance. After retries are exhausted or a configuration error is resolved, **Retry Google export** starts another background attempt. No retry delay holds an HTTP request or a worker thread open. Local `bin/dev` uses Rails' normal in-process asynchronous adapter; production uses the durable queue configured in `config/environments/production.rb`.

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

The default first data row is 3, with headers in row 2, matching the existing workbook. The tab name is configurable. Publishing checks the headers, preserves existing records, and refuses ambiguous or already-used invoice numbers. Column D receives only the first nonblank contact email, or stays empty when no email is available, so it works with a People column. Values are written as raw data, so descriptions and invoice numbers cannot become spreadsheet formulas. Amount Owed must be zero for InvoiceMe to import a full payment. Enter the full invoiced amount in Amount Received and enter the payment method and deposit date. Use a spreadsheet date cell or an ISO date such as `2031-09-15`. Record partial payments in InvoiceMe and use **Sync to Google** to update the ledger.

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

   For local development, optionally add `http://localhost:3000/google/callback` and export `APP_URL=http://localhost:3000`.
6. Set `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` in the ignored `.kamal/secrets` file on your development machine. Preserve the existing `SECRET_KEY_BASE` so stored Google tokens remain decryptable.
7. Apply the new environment:

   ```sh
   bin/kamal deploy
   ```

8. Sign into InvoiceMe, open **Year & settings**, choose **Connect Google account**, and authorize the treasurer account. Check the folder, PDF folder, tab name, and header row before the first publish. The refresh token is encrypted in SQLite using keys derived from `SECRET_KEY_BASE`.

Follow Google's [web-server OAuth guide](https://developers.google.com/identity/protocols/oauth2/web-server) for the consent setup. Revoking access in Google invalidates the connection; reconnect from InvoiceMe. The Disconnect button removes the app's locally stored token; it does not revoke the OAuth grant in your Google account.

## Local development

This is a standard Rails 8.1 application using Ruby 4.0.10, SQLite, React 19, Inertia Rails, Vite, Bootsnap, and the default Solid Queue/Cache/Cable adapters. The production Dockerfile extends the Rails template with a Node build stage for Vite and retains Thruster on port 80. Node is not needed in the runtime container.

```sh
bin/setup
```

The setup script installs dependencies, prepares the database, and starts `bin/dev` at **http://localhost:3000**. Node.js 26 LTS is required alongside Ruby. `bin/dev` runs Rails and Vite together using the generated `Procfile.dev`. Use `bin/setup --skip-server` to prepare without starting the server, and `bin/dev` or `bin/rails server` for subsequent runs. Production assets are compiled during the Docker build; local development uses the Rails asset pipeline.

## Authentication

Authentication comes from **`bin/rails generate authentication`**: `User` with `has_secure_password`/bcrypt, persisted `Session` records, signed session cookies, `Current.user`, rate-limited sign-in, and token-based password resets. Public account registration is not enabled. The old shared password gate and development-only password have been removed.

Create your first local account using the Rails console:

```ruby
User.create!(email_address: "treasurer@eotfoa.ca", password: "choose-your-own-password", password_confirmation: "choose-your-own-password")
```

For initial provisioning during deployment, `db:seed` accepts `ADMIN_EMAIL` and `ADMIN_PASSWORD`. They create an account only when it does not exist and **never overwrite an existing password**. Subsequent authentication uses the database password digest. The production treasurer account was provisioned with the previous password.

The generated password-reset mailer uses Action Mailer and Active Job. Development emails appear in the Rails log. For production delivery, configure `SMTP_ADDRESS`, `SMTP_USERNAME`, and `SMTP_PASSWORD` in `.kamal/secrets`; `SMTP_PORT` defaults to 587 and `MAILER_FROM` is configured in `config/deploy.yml`. Password-reset delivery requires those SMTP settings. No production SMTP credentials have been supplied yet.

## Association expenses

Open **Association expenses** for the selected invoice year to record vendor bills and member reimbursements. Capture the full amount, date, expense category and any itemized costs. An item can use its own category for the year-end breakdown. The expense category covers items with no override and any remaining balance. Record paid status, payment date, method, and cheque number as they become available.

In **Year & settings**, set **Financials folder for expenses** to the Google Drive folder for that year. With the treasurer Google account connected, choose **Sync to Google Sheets** from the register. InvoiceMe creates a native yearly workbook in that folder and refreshes its Expenses, Line items and By category tabs on subsequent syncs. The income ledger and invoice export folders use their existing settings. Make edits in InvoiceMe, then sync the updated register from the same screen.

## Deployment with Kamal

Run deployment commands from this checkout. `config/deploy.yml` configures service **invoice-me**, hostname **invoices.callummacleod.ca**, OVH host **144.217.240.192**, the local registry on port 5555, and a native AMD64 remote builder on the VM. Kamal handles the build, push/pull, release containers, health checks, proxy route, asset bridging, logs, and rollback.

Secrets are loaded by Kamal from the ignored `.kamal/secrets` file. For a new checkout, copy `.kamal/secrets.example`, fill it in, and securely supply `config/master.key`. Keep `SECRET_KEY_BASE` stable: it protects stored Google refresh tokens. Configuration uses standard Rails credentials and exported environment variables; local Rails does not automatically load the old production env file.

```sh
# First installation on a new host:
bin/kamal setup

# Normal release from committed source:
bin/kamal deploy

# Provision the initial account/year, without resetting existing records:
bin/kamal app exec --reuse "bin/rails db:seed"

# Operations:
bin/kamal details
bin/kamal logs
bin/kamal console
bin/kamal rollback <previous-version>
```

The `invoice_me_storage` named volume contains the existing primary database and Rails' separate production cache, queue, and cable databases. It was retained during migration from Compose. No host application port is published; the shared Kamal proxy routes HTTPS to the active release's Thruster port. Other apps use their own services and volumes.

Production migrations run through the generated Docker entrypoint's `db:prepare`. `/up` is the health endpoint. Google exports run outside web requests using the existing Solid Queue supervisor in Puma; no additional service or proxy route is needed. The retired Compose deployment is no longer used; its original source and a pre-migration database snapshot are retained on the VM for recovery.

## Checks

```sh
bin/ci
```

This is Rails' default CI runner: setup, Omakase RuboCop, Bundler and npm audits, strict TypeScript checks, the React/StyleX production build, exact-decimal frontend tests, Brakeman, Rails/Inertia tests, and seed verification. The tests cover generated authentication/password-reset behavior, session revocation, invoice calculations and locking, PDF/ODT rendering and privacy, Horizon imports, and resumable Google writes against a fake API. Live Google publishing still needs an OAuth connection and first-publish verification.

## Backups and recovery

`bin/backup` uses `bin/kamal app exec` to run SQLite's `.backup` in the active release and writes a consistent snapshot under `/rails/storage/backups` in `invoice_me_storage`. Keep encrypted copies **off the VM**, together with the matching production secrets and Rails master key. An off-server backup schedule is not configured automatically.

Restore only while the InvoiceMe service is stopped, with a backup of the current volume first. Restore `production.sqlite3` with UID/GID 1000, remove stale WAL/SHM files only while stopped, then start the release using Kamal. Preserve the same `SECRET_KEY_BASE`, and verify restored records before retrying Google publications.

## Horizon integration

InvoiceMe accepts downloaded CSV/XLSX files through the upload and review workflow. The native master-fees export is detected automatically, including its repeated name/position/fee groups after the fixed game fields. The import retains every official, position, and Paid By Team value, sums fees exactly, and shows a count of excluded meetings. CSV layouts vary, so the importer supports explicit mapping and separate position-name/fee pairs.

### Sync games from Horizon

On **Games & officials**, choose **Sync from Horizon** for the connected organization. InvoiceMe fetches the selected invoice year's January–December schedule in a background job and shows a review with new, changed, and unchanged games, including before-and-after officials, fees, and cancellation information. Applying the review creates or updates games by Horizon event ID in a transaction; invoice links, invoicing marks, and existing CSV source details are retained. Games absent from a response are not deleted. Reviews expire after two hours and can be discarded. The CSV workflow remains available.

Assignment fees are the sum of Horizon's fee, travel, per diem, tolls, and other fees; deductions are excluded. These amounts are reference figures, not proof of payment. The game sync preserves existing CSV Paid By Team values and leaves that CSV field blank for new games. Review fee changes carefully, especially for games already linked to invoices. The sync requires complete, consistent pagination, rejects duplicate or incomplete events, and refuses to apply if a game changed since the review. It makes one call per schedule page plus a token exchange when needed, with no automatic request retries. To conserve the free-tier quota, a sync stops if Horizon reports more than 10 pages; it does not apply partial results. Simultaneous syncs are limited to one per application.

### Officials payments

Open **Officials payments** and choose **Pull from Horizon** to populate the selected year's earnings register. The import reads published, non-cancelled games from January 1 through December 31, including upcoming games in the selected year. It excludes games marked vouchered or paid by the team. The register shows any games with ambiguous payer or cancellation fields. Game fees are grouped by Horizon user ID, and assignment travel, per diem, tolls, and other fees populate Travel/OT.

Choose **Pull from Horizon** again any time the source fees or travel amounts change. InvoiceMe replaces the imported amounts on draft payments and returns changed drafts to review. Manual fees, deductions, named adjustments, and recorded cheques are retained. The register flags cheques whose underlying Horizon assignments changed.

Compare the imported assignments with Horizon's payroll report before checking the review box. Use manual adjustments for fees on payable cancelled games, already-issued payments, standalone payroll adjustments, and other differences. The register applies the 2025 association-fee schedule to game fees and keeps the other deductions and credits editable. Reviewed statements can be downloaded as PDF or editable documents, or generated in the connected treasurer's My Drive.

Use **Enter payment amounts** to edit individual cells or paste a range from a spreadsheet. Use **Additional items** to add or edit named credits and deductions across officials. Changed payments return to review, and recorded cheques lock their earnings and payment numbers. Payment numbers start at 1 each year and apply to positive net earnings. Officials with zero or negative net earnings appear under **No cheque due**. Gaps in draft payment numbers close after the highest recorded payment number. **Preview statement** opens the saved statement before review. After all officials are reviewed, **Export final Google Sheet** creates a new workbook in the treasurer's Drive with the payment register and an itemized adjustments tab.

Use **Assign cheque numbers** to enter a starting cheque number and preview proposed numbers in payment order. **Record cheque numbers** saves the reviewed batch. **Download statements PDF** produces one file with all saved statements in register order, including officials under **No cheque due** at the end.

### Horizon API and connection

Set `HORIZON_APP_ID` and `HORIZON_APP_KEY` in the ignored `.kamal/secrets` file and deploy with Kamal. Never commit credentials. In **Year & settings**, choose **Connect Horizon** and approve read-only organization access. Horizon may offer multiple organizations; select only those you want to connect. InvoiceMe encrypts each authorization code and access token in SQLite using keys derived from `SECRET_KEY_BASE`, which must remain stable. Use **Test read access** for a single schedule request for today. Disconnect deletes local credentials; revoke access separately in Horizon. No game data is imported by this test.

If the ignored Kamal secrets file reads from a separate credential file, use its absolute path in the local secrets loader. Kamal evaluates relative paths in the deployment checkout, including when the loader is linked from another checkout. After deploying, `GET /api/v1/official_payments/imports?season_id=…` reports whether Horizon credentials are configured and the register can pull earnings.

The integration requests only `read_organization`. Horizon enforces the user's roles and approved scopes; methods that change Horizon data require additional permissions and an appropriately authorized token. The client makes no automatic retries or pagination requests. A token exchange can return HTTP 409 if Horizon already has a valid token that InvoiceMe did not receive (for example after a dropped response); wait for that token to expire before retrying. Authorization codes last one year and access tokens last 30 minutes. The app serializes token exchanges on its shared storage volume and reuses the token until expiry.

The [Horizon Developer API](https://www.horizonwebref.com/developer) is available through named resource methods. `HorizonConnection.find(id).access_token_for_request` obtains the token; construct `Horizon::Client.new(access_token: token)` and call, for example, `client.schedule.list(start_date: "2031-01-01", end_date: "2031-01-31", cancelled: false)` or `client.teams.find("fictional-id")`. Methods return the complete Horizon response, including pagination metadata. Each call is one API request. The available resources and methods are:

| Resource | Methods |
| --- | --- |
| `contact_groups` | `list`, `find`, `create`, `update`, `delete_many`, `add_members`, `remove_members`, `add_member`, `remove_member` |
| `custom_fields` | `list`, `find`, `find_answer`, `save_answer`, `delete_answers`, `delete_answer` |
| `event_codes`, `leagues`, `locations`, `teams` | `list`, `find`, `create`, `update`, `deactivate`, `deactivate_many` |
| `manual_ranks` | `list`, `find`, `update` |
| `payroll_adjustments` | `list`, `find`, `create`, `update`, `update_many`, `delete`, `delete_many` |
| `positions` | `list`, `find`, `deactivate`, `deactivate_many` |
| `schedule` | `list`, `find`, `create`, `update`, `cancel_many`, `remove` |
| `users` | `list`, `find`, `find_permission`, `create`, `update_permission`, `delete_permission`, `delete_many` |

Resource methods take path IDs as positional arguments and documented query parameters as keywords; their accepted names are listed in the corresponding `app/services/horizon/` resource class. The API reference defines value types and conditional requirements. Horizon labels the bulk contact-group member and payroll-adjustment IDs as path parameters despite omitting them from the path; the wrapper sends them in the JSON body. The reference does not document manual-rank update fields, so that method accepts arbitrary keyword fields. Those cases require live verification. For newly introduced or undocumented endpoints, `client.request` remains available. Errors omit response bodies and distinguish configuration, authentication, rate limit, transient network/server, and response failures.

Horizon exports contain private information. Keep downloaded exports outside Git. Automated fixtures use fictional names, teams, locations, game IDs, dates, and fees; the normal `HorizonWebRef_Master_Fees_*.csv` export filename pattern is ignored.

## Frontend

All application screens are React pages in `app/frontend/pages`, rendered by the existing Rails controllers through [Inertia Rails](https://inertia-rails.dev/). Navigation and forms use Inertia rather than a separate JSON API or browser router. Rails owns authentication, sessions, CSRF protection, validation, and authorization. Validation redirects use the adapter’s error props, preserving entered form values. The generated Rails password-reset flow remains on the server.

Vite builds the frontend under `public/assets/vite`, inside Kamal’s existing asset bridge so old tabs retain their versioned assets during releases. `bin/dev` runs the Rails and Vite servers with React hot reload; production uses only compiled assets. PDF and Google Docs/ODT generation remain server-side. The React document preview retains the supplied invoice design.

## UI styling and TypeScript

Application components and page props use strict TypeScript in `app/frontend` (`npm run typecheck`). Shared types describe the Rails response props, invoice forms, games, and import mappings. Inertia’s shared props and validation error types are augmented centrally. The money tests run the typed calculation module using Node 26’s native TypeScript support.

The application UI uses [StyleX](https://stylexjs.com/docs/learn/installation/vite/vite-react). Design tokens live in `styles/tokens.stylex.ts`, shared UI styles in `styles/ui.stylex.ts`, and shell styles alongside the Layout component. Apply styles with `stylex.props`; use explicit variants and media queries rather than global class selectors. A small reset is the only global UI CSS. The invoice preview and server document share the scoped `invoice.css` contract so exports retain their existing appearance.

The official StyleX Vite plugin extracts atomic CSS at build time and adds it to the manifest alongside the typed Inertia entrypoint. The build checks that the extracted CSS, design tokens, and responsive rules are present. Rails loads the generated stylesheet through Vite Rails; Kamal bridges it with the other versioned assets. Development uses a linked StyleX stylesheet and Vite events to refresh it across the separate Rails/Vite origins, without runtime style injection or loosening the production content security policy.

## Game browser and contacts

The master game list and invoice game browser share server-side filters for home team, away team, code, venue, official name, inclusive date range, and invoice/workbench link status. Text filters match part of a name and treat `%`, `_`, and backslashes literally. Filters combine and remain applied when paging. Results stay bounded to 25 games. Selecting games in the wide invoice browser retains selections across filters and pages, with a selected-game summary in the editor. Crew fee tables and original source data load only when opened; imported fees are reference amounts rather than proof of payment.

Link badges distinguish saved invoices from the signed-in user's autosaved workbench selections. Link filters include those workbenches without exposing another user's private draft titles or notes. Selecting an already-linked game is allowed and its existing links remain visible.

Contacts are private to each user and reusable across years. Save a name, organization, email, phone, mailing address, and private notes in Contacts. An invoice can have multiple contacts, added from saved contacts or entered manually. The first saved contact fills in the recipient and address; additional contacts are appended without replacing those fields. Names and emails remain separately editable and autosave normally. Reorder or remove contacts in the editor. Invoice previews, PDFs, and Google Docs show only their names, while the master spreadsheet receives the first nonblank email. Editing or deleting a saved contact does not change existing invoices or drafts, and private contact notes are not copied to invoices. Older combined contact fields remain readable and become separate name/email entries when edited.

## Draft workbench

Drafts autosave to the server after a 700 ms pause in typing. Incomplete fields, raw quantities/rates, notes, line additions/removals, and game selections are retained independently of the validated invoice. Create several drafts, switch between them in the editor, or resume them from the register's workbench shelf and the searchable Draft workbench page. Workbenches belong to the signed-in user and invoice year; GET requests and hover prefetch never create drafts.

Existing saved drafts are added to the sole account's workbench during the upgrade. With multiple accounts, Edit draft explicitly opens or creates that account's workbench instead of guessing ownership.

In-app navigation waits for pending saves. The editor shows saving/saved/error feedback, retries interrupted saves, and warns before closing a document with unsaved changes. Saves are serialized so edits made during a request are sent afterward. Revision checks prevent another tab from silently overwriting a draft; conflicting edits can be compared with the saved version or saved as a separate draft. Draft content is not stored in localStorage.

Save & preview applies the workbench to the normal validated invoice in a transaction. Publishing still requires an explicit action, and unpreviewed workbench edits block publishing an older invoice snapshot. Workbench writes and finalization share the invoice lock, including a recheck after Google preflight. Finalized invoices remain immutable. Removing a workbench discards its autosaved edits while retaining any invoice already saved for preview.

## Performance

Registers and game searches return 25 records per page. Game summaries select only scalar fields and SQL-computed official counts; officials and original source rows load when a game's details are opened. The invoice picker searches on the server and keeps selected games visible across pages without replacing unsaved form data. Invoice lists preload only the visible records' line items and payments; season totals use grouped SQL with exact per-line cent rounding. Search and pagination use partial Inertia reloads to skip season totals and unrelated props. Composite indexes cover list ordering. Invoice detail serialization preloads linked invoice references instead of querying once per game.

Page JavaScript is split into lazy chunks. Internal GET links prefetch their Inertia response and page chunk on hover, with a 15-second cache. Mutations, year changes, and sign-out clear that cache. Sidebar navigation starts on primary mousedown; keyboard, touch fallback, and modified clicks retain normal behavior. Mutation links are never prefetched. Currency and date formatters are reused, and the game picker is memoized so typing invoice fields does not re-render its list.

Reproduce the benchmark with `RAILS_ENV=test bin/rails runner script/benchmark_workspace.rb`. It creates only fictional data inside a rolled-back transaction and refuses development/production. The workload has 500 games, 250 invoices, 1,250 line items, and 125 payments. These are local warm request medians (11 samples after five warm-ups, Ruby 4.0.9), not production network timings. Compared with commit `851d01e`:

| Inertia response | Before → after | JSON bytes before → after | Active Record objects before → after |
| --- | --- | --- | --- |
| Invoice register | 25.61 → 14.12 ms | 61,384 → 6,773 | 1,630 → 167 |
| Games | 27.71 → 7.49 ms | 698,240 → 8,442 | 1,255 → 80 |
| New invoice | 25.87 → 8.01 ms | 147,502 → 9,122 | 1,255 → 80 |

The register uses more small SQL queries to aggregate season totals, while loading 90% fewer model objects. Browser checks also cover hover data/chunk requests, navigation before mouse release, keyboard navigation, pagination, detail loading, unsaved field/selection retention, and cache invalidation when changing years. CI checks pagination, cross-year detail isolation, per-line rounding, partial reloads, and a query budget for invoices linked to many games.
