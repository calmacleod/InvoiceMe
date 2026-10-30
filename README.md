# InvoiceMe

A private EOTFOA treasurer workspace for Horizon game imports, invoice preparation, PDF/Google Docs generation, payment tracking, and the annual Google Sheets ledger.

## Daily workflow

1. Open **Games & officials → Import Horizon file**. Upload a CSV or XLSX export, match columns, review the totals, then import. Files can contain one row per game, one row per assignment, or separate name/fee columns for each position. All original columns remain available in each game's Source details. ISO dates are accepted automatically; explicitly choose the format of other dates.
2. Choose **Create invoice**. Enter a unique invoice number, recipient, ledger description, dates, and line items. Quantities support three decimal places; rates use exact cents. Optionally select games. Game fees are reference information; linking games does not change invoice prices. The same game can be linked to multiple invoices, with a visible warning.
3. Save the draft, review the preview, and download its PDF if desired. Private notes never appear in the PDF or Google Doc.
4. Choose **Finalize & save to Google**. The app queues a background export and shows its progress on the invoice page. You can leave the page and return later. The job validates the destination and checks for an existing invoice number, freezes the issuer/address/payment details and destination, creates a native Google Doc and PDF, and records the ledger row. After finalization, invoice details cannot be edited. Make corrections using a new invoice number. Private notes remain editable.
5. Record payments against finalized invoices. **Sync to Google** updates the received amount, balance, last payment method, and deposit date. Payment recording is local; syncing is a separate explicit action.

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

   For local development, optionally add `http://localhost:3000/google/callback` and export `APP_URL=http://localhost:3000`.
6. Set `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` in the ignored `.kamal/secrets` file on your development machine. Preserve the existing `SECRET_KEY_BASE` so stored Google tokens remain decryptable.
7. Apply the new environment:

   ```sh
   bin/kamal deploy
   ```

8. Sign into InvoiceMe, open **Year & settings**, choose **Connect Google account**, and authorize the treasurer account. Check the folder, PDF folder, tab name, and header row before the first publish. The refresh token is encrypted in SQLite using keys derived from `SECRET_KEY_BASE`.

Follow Google's [web-server OAuth guide](https://developers.google.com/identity/protocols/oauth2/web-server) for the consent setup. Revoking access in Google invalidates the connection; reconnect from InvoiceMe. The Disconnect button removes the app's locally stored token; it does not revoke the OAuth grant in your Google account.

## Local development

This is a standard Rails 8.1 application using Ruby 4.0.9, SQLite, React 19, Inertia Rails, Vite, Bootsnap, and the default Solid Queue/Cache/Cable adapters. The production Dockerfile extends the Rails template with a Node build stage for Vite and retains Thruster on port 80. Node is not needed in the runtime container.

```sh
bin/setup
```

The setup script installs dependencies, prepares the database, and starts `bin/dev` at **http://localhost:3000**. Node.js 24 is required alongside Ruby. `bin/dev` runs Rails and Vite together using the generated `Procfile.dev`. Use `bin/setup --skip-server` to prepare without starting the server, and `bin/dev` or `bin/rails server` for subsequent runs. Production assets are compiled during the Docker build; local development uses the Rails asset pipeline.

## Authentication

Authentication comes from **`bin/rails generate authentication`**: `User` with `has_secure_password`/bcrypt, persisted `Session` records, signed session cookies, `Current.user`, rate-limited sign-in, and token-based password resets. Public account registration is not enabled. The old shared password gate and development-only password have been removed.

Create your first local account using the Rails console:

```ruby
User.create!(email_address: "treasurer@eotfoa.ca", password: "choose-your-own-password", password_confirmation: "choose-your-own-password")
```

For initial provisioning during deployment, `db:seed` accepts `ADMIN_EMAIL` and `ADMIN_PASSWORD`. They create an account only when it does not exist and **never overwrite an existing password**. Subsequent authentication uses the database password digest. The production treasurer account was provisioned with the previous password.

The generated password-reset mailer uses Action Mailer and Active Job. Development emails appear in the Rails log. For production delivery, configure `SMTP_ADDRESS`, `SMTP_USERNAME`, and `SMTP_PASSWORD` in `.kamal/secrets`; `SMTP_PORT` defaults to 587 and `MAILER_FROM` is configured in `config/deploy.yml`. Password-reset delivery requires those SMTP settings. No production SMTP credentials have been supplied yet.

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

This version imports downloaded CSV/XLSX files. The native master-fees export is detected automatically, including its repeated name/position/fee groups after the fixed game fields. Every official and position is retained, the fees are summed exactly, the Paid By Team field is retained, and meeting entries are excluded with a visible count. These are fee amounts, not evidence that an official has actually been paid. It does not scrape the signed-in website and does not assume access to Horizon's Developer API. Export the complete filtered schedule/payroll report yourself and use the upload/review workflow. CSV layouts vary; explicit mapping and separate position-name/fee pairs are supported. API synchronization can be added once EOTFOA's API access and the actual API contract are available.

Horizon exports contain private information. Keep downloaded exports outside Git. Automated fixtures use fictional names, teams, locations, game IDs, dates, and fees; the normal `HorizonWebRef_Master_Fees_*.csv` export filename pattern is ignored.

## Frontend

All application screens are React pages in `app/frontend/pages`, rendered by the existing Rails controllers through [Inertia Rails](https://inertia-rails.dev/). Navigation and forms use Inertia rather than a separate JSON API or browser router. Rails owns authentication, sessions, CSRF protection, validation, and authorization. Validation redirects use the adapter’s error props, preserving entered form values. The generated Rails password-reset flow remains on the server.

Vite builds the frontend under `public/assets/vite`, inside Kamal’s existing asset bridge so old tabs retain their versioned assets during releases. `bin/dev` runs the Rails and Vite servers with React hot reload; production uses only compiled assets. PDF and Google Docs/ODT generation remain server-side. The React document preview retains the supplied invoice design.

## UI styling and TypeScript

Application components and page props use strict TypeScript in `app/frontend` (`npm run typecheck`). Shared types describe the Rails response props, invoice forms, games, and import mappings. Inertia’s shared props and validation error types are augmented centrally. The money tests run the typed calculation module using Node 24’s native TypeScript support.

The application UI uses [StyleX](https://stylexjs.com/docs/learn/installation/vite/vite-react). Design tokens live in `styles/tokens.stylex.ts`, shared UI styles in `styles/ui.stylex.ts`, and shell styles alongside the Layout component. Apply styles with `stylex.props`; use explicit variants and media queries rather than global class selectors. A small reset is the only global UI CSS. The invoice preview and server document share the scoped `invoice.css` contract so exports retain their existing appearance.

The official StyleX Vite plugin extracts atomic CSS at build time and adds it to the manifest alongside the typed Inertia entrypoint. The build checks that the extracted CSS, design tokens, and responsive rules are present. Rails loads the generated stylesheet through Vite Rails; Kamal bridges it with the other versioned assets. Development uses a linked StyleX stylesheet and Vite events to refresh it across the separate Rails/Vite origins, without runtime style injection or loosening the production content security policy.

## Game browser and contacts

The master game list and invoice game browser share server-side filters for home team, away team, code, venue, official name, inclusive date range, and invoice/workbench link status. Text filters match part of a name and treat `%`, `_`, and backslashes literally. Filters combine and remain applied when paging. Results stay bounded to 25 games. Selecting games in the wide invoice browser retains selections across filters and pages, with a selected-game summary in the editor. Crew fee tables and original source data load only when opened; imported fees are reference amounts rather than proof of payment.

Link badges distinguish saved invoices from the signed-in user's autosaved workbench selections. Link filters include those workbenches without exposing another user's private draft titles or notes. Selecting an already-linked game is allowed and its existing links remain visible.

Contacts are private to each user and reusable across years. Save a name, organization, email, phone, mailing address, and private notes in Contacts. The invoice editor's saved-recipient picker searches contacts on demand and copies recipient, contact name/email, and address into the draft. Those fields remain editable and autosave normally. Editing or deleting a contact does not change existing invoices or drafts, and private contact notes are not copied to invoices.

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
