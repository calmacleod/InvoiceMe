# InvoiceMe API v1

All routes start at `/api/v1`. Send `Authorization: Bearer <key>` over HTTPS. Keys belong to a user: contacts and workbench drafts are private to that user; seasons, games, invoices and association expenses are shared, matching the application. Keys are read-only unless issued with write access. Keep them secret; the server stores only a SHA-256 digest. There is no cookie authentication or CORS access for API routes.

On the server, issue a key with `EMAIL=user@example.com NAME=automation WRITE=true bin/rails api_keys:issue`. Omit `WRITE=true` for a read-only key. The token is printed once. Revoke it with `ID=<key-id> bin/rails api_keys:revoke`. Protect command output. Create separate keys for each integration so they can be revoked independently.

JSON requests use `Content-Type: application/json`. Errors have an `error` string or array; invalid credentials return 401, insufficient access 403, missing resources 404, validation errors 422, and concurrent or blocked edits 409. Lists return `data` and `pagination`; use `page` and `per_page` (10, 25, 50 or 100). Monetary response fields ending in `_cents` are integer cents; input `rate` and payment `amount` are decimal currency strings.

- `GET /seasons`, `GET /seasons/:id`, `POST /seasons`, `PATCH /seasons/:id`: list, inspect, create or update years. Writes wrap fields in `season`: `year`, Google folder and spreadsheet IDs (including `financials_folder_id` for expenses), `sheet_name`, `ledger_start_row`, and `issuer` (name, payable_to, treasurer, email, address, payment_instructions).
- `GET /contacts`, `GET /contacts/:id`, `POST /contacts`, `PATCH /contacts/:id`, `DELETE /contacts/:id`: manage the key user's contacts. List accepts `q`. Writes wrap `name`, `organization`, `email`, `phone`, `address`, and `notes` in `contact`.
- `GET /games?season_id=...`, `GET /games/:id`: list and inspect games, including official and source data. Filters include `q`, `home_team`, `away_team`, `code`, `location`, `official`, `date_from`, `date_to`, and `link_status` (linked, unlinked, invoiced, workbench). Sort with `sort` and `direction`.
- `PATCH /games/invoicing_status`: JSON body `season_id`, `game_ids` array, and boolean `already_invoiced`. All IDs must belong to the season.
- `POST /games/import`: multipart `season_id`, `file` (CSV or XLSX), optional `date_format` (`%m/%d/%Y`, `%d/%m/%Y`, `%Y-%m-%d`) and `mapping` (JSON string). Without `commit=true`, returns a preview and suggested mapping; repeat the request with the file, mapping and `commit=true` to import. Errors prevent all writes. This can update existing games by external ID.
- `GET /invoices?season_id=...`, `GET /invoices/:id`, `POST /invoices`, `PATCH /invoices/:id`, `DELETE /invoices/:id`: list, inspect and manage invoices. List accepts `q`. Create requires `season_id`; writes wrap fields in `invoice`: `number_suffix`, `recipient`, `recipient_address`, `description`, `issued_on`, `due_on`, `public_notes`, `private_notes`, `contacts` (array of name/email), `game_ids`, and `line_items_attributes` (description, quantity, rate, position, amount_only; existing lines also accept id and _destroy). Creation allocates the next number using the configured Google ledger. Finalized or exporting invoices cannot be edited or deleted; previously finalized invoices are retained.
- `GET /invoices/:id/pdf`: generated invoice PDF. `POST /invoices/:id/publish` queues Google export and returns its progress; inspect the invoice's `export` field for status. `POST /invoices/:id/reopen` returns an eligible invoice to draft. `POST /invoices/:id/payment` accepts `amount`, `received_on`, `method`, and optional `notes`. `PATCH /invoices/:id/notes` accepts `private_notes` even on a finalized invoice.
- `GET /drafts?season_id=...`, `GET /drafts/:id`, `POST /drafts`, `PATCH /drafts/:id`, `DELETE /drafts/:id`: manage the key user's workbench drafts. Create requires `season_id` and `data`, and optionally `invoice_id`, `invoice_group_id`, and `client_key`. Update requires `data` and the current `lock_version`; stale updates return 409. Data accepts the invoice fields above and line-item `key` values. Each line may include `private_breakdown` with a `notes` string and an `entries` array of `{key, description, amount}` strings. Breakdowns belong to the API key user, survive preview, and are excluded from invoice documents. `POST /drafts/:id/preview` with `lock_version` saves the workbench as an invoice, allocating a number if needed.
- `GET /google` reports configuration and connected account; `DELETE /google` disconnects it. Connecting Google requires the existing browser OAuth flow.

## Association expenses

- `GET /expenses?season_id=...` lists the selected year's expenses with `data`, `pagination`, `categories` and `summary`. Optional filters are `query` (payee, description, reference or cheque number), `category` (expense or item category, case-insensitive) and `status` (`paid` or `unpaid`). Summary amounts and `by_category` always cover the entire selected year.
- `GET /expenses/:id` returns the expense with ordered `line_items`, `itemized_cents`, `remainder_cents` and its current `lock_version`. `POST /expenses` requires `season_id` and an `expense` object. `PATCH /expenses/:id` accepts the same fields and applies only supplied values. Pass the current `lock_version` to reject a stale edit with 409.
- `DELETE /expenses/:id` deletes the expense and its items and returns 204. The next successful Sheet sync removes the corresponding rows.
- `GET /seasons/:id/expense_sheet` returns the sync status. `POST /seasons/:id/expense_sheet` queues a sync and returns 202. Repeated requests while a sync is active share that run. Set `financials_folder_id` on the season using a Drive folder ID or URL and connect the treasurer Google account through Settings.
- The status fields are `ready`, `folder_configured`, `status` (`idle`, `queued`, `running`, `succeeded` or `failed`), `active`, `stale`, `url`, `synced_at` and `error`. Sync creates or refreshes one `<year> Association Expenses` workbook in the selected folder. Its `Expenses`, `Line items` and `By category` tabs reflect a complete season snapshot. Make changes in InvoiceMe and sync again.

Expense creation requires `payee`, `description`, `incurred_on` (ISO date), `category` (custom text), and a positive integer `total_cents`. Optional fields include `reference`, `notes` and a boolean `paid`, which defaults to false. For paid entries, `paid_on`, `payment_method` and `cheque_number` are optional. Set these fields to `null` or blank in the same request when reverting a paid expense to unpaid.

Omitting `line_items` preserves the saved items. Sending the array replaces the full ordered list, and `[]` clears it. Include existing item IDs to retain them. Each item accepts `description`, integer `amount_cents` and an optional category override. Use a negative line for a discount. The itemized sum cannot exceed the expense total. The expense category covers each item without an override and any unitemized balance.

```json
{
  "season_id": 12,
  "expense": {
    "payee": "Example Community Centre",
    "description": "Committee training event",
    "incurred_on": "2031-07-18",
    "category": "Training",
    "total_cents": 18050,
    "paid": true,
    "paid_on": "2031-07-21",
    "payment_method": "Cheque",
    "cheque_number": "0032",
    "line_items": [
      { "description": "Room rental", "amount_cents": 15000 },
      { "description": "Refreshments", "category": "Food", "amount_cents": 3050 }
    ]
  }
}
```

## Invoice groups

- `GET /invoice_groups?season_id=...` lists the selected season’s groups. `GET /invoice_groups/:id` returns the shared game IDs, whether those links are locked, saved invoice summaries and their combined total, and the key user’s open workbench drafts.
- `POST /invoice_groups` takes `season_id` and one of `invoice_id`, `draft_id`, or `game_ids`. An existing invoice or workbench returns its current group if it already belongs to one. Creating a group from a finalized invoice keeps the existing game links and invoice contents.
- `PATCH /invoice_groups/:id` accepts the current `lock_version` and a `name`, `game_ids`, or both. Once a group has a finalized or exporting invoice, its name remains editable and its game selection is locked.
- `GET /invoice_groups/:id/attachment?invoice_id=...` returns the IDs of games to add or remove, any blocking issue, and a signed `token` valid for 30 minutes. `POST /invoice_groups/:id/attach_invoice` takes the `invoice_id` and requires that token as `review_token` when the game links differ. It preserves invoice line items and rejects changes to the existing game links of a finalized invoice.
- To create a separate invoice in a group, pass `invoice_group_id` to `POST /drafts`, with the new payer and charges in `data`. Omit `data.game_ids` to inherit the group’s links. Preview the draft to allocate its own invoice number and save its own charges.

## Officials’ payments

- `GET /official_payments?season_id=...` lists the shared season register in payment-number order. `GET /official_payments/:id` adds the official’s imported assignments and Horizon totals. Both include calculated earnings, deductions, cheque status, named adjustments, and the current `lock_version`. Currency fields in responses use integer cents.
- `GET /official_payments/totals?season_id=...` returns `season_id` and a `totals` object that sums the register’s amount fields across the entire season. `additional_items_cents` sums the named credits and deductions. The game fee and travel/OT totals already include their respective adjustment amounts.
- `POST /official_payments` creates a manual payment with `season_id` and `official_payment: { "official_name": "Example Official" }`. The server assigns the season’s next payment number.
- `PATCH /official_payments/:id` accepts `official_payment` with the current `lock_version` and any of `game_fee_adjustment`, `travel_ot_adjustment`, `evaluations`, `prepayment_refund`, `registration`, `banquet`, `next_year_prepayment`, `other`, `adjustments`, `reviewed`, `cheque_number`, `deposited_on`, and `cheque_delivery`. Send amounts as decimal dollar strings and `reviewed` as a JSON boolean. An earnings edit clears review unless the request explicitly sets `reviewed: true`. Cheques require reviewed, positive earnings. Send a separate request to clear cheque details before changing previously recorded earnings.
- `PATCH /official_payments/bulk_update` accepts `season_id` and a `payments` array. Each row requires the payment `id` and current `lock_version`, plus an `amounts` object, an `adjustments` array, or both. It applies the batch atomically, clears review on changed rows, and returns `updated` and `data` with the changed records. A stale, duplicate, out-of-season, or cheque-locked row returns 409 and rolls back the batch.
- For both update routes, an omitted amount or adjustment field preserves its value. A blank amount clears that amount. Supplying `adjustments` replaces the full list with `[{ "label": "Training credit", "amount": "12.50" }]` or clears it with `[]`.
- `GET /official_payments/imports?season_id=...` lists Horizon import runs and connection choices. `horizon_configured` reports whether the deployment has Horizon application credentials. `can_import` also requires an organization connection and a season that has started. `POST /official_payments/imports` takes `season_id` and `horizon_connection_id`, queues an earnings pull, and returns 202. It includes eligible published games from January 1 through December 31 of the selected season, including upcoming games. Run it again to refresh imported draft earnings. Poll `GET /official_payments/imports/:id?season_id=...` for status, excluded games, and cheque-locked records that differed from Horizon.
- `GET /official_payments/:id/preview` returns an inline PDF before review. The reviewed statement is downloadable at `GET /official_payments/:id/pdf` and `GET /official_payments/:id/odt`. `POST /official_payments/:id/google_doc` creates or updates the reviewed statement in Google Drive and returns its ID and URL.
- `POST /official_payments/export_sheet` takes `season_id`, exports the reviewed register to Google Sheets, and returns the spreadsheet ID and URL.

Publishing, payments, imports, and invoice deletion affect real records or external Google documents. Review inputs before issuing write requests. The API does not provide an automatic retry guarantee for non-idempotent actions such as payments.
