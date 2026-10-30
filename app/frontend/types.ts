import type { ReactElement } from "react";
import type { ComponentType } from "react";

export type InvoiceStatus =
  "Draft" | "Needs sync" | "Paid" | "Part paid" | "Outstanding";
export type SeasonSummary = { id: number; year: number };
export type SharedProps = {
  auth: { email: string } | null;
  seasons: SeasonSummary[];
  current_season: SeasonSummary | null;
  flash: Record<string, string>;
  today: string;
  section: string;
  logo_url: string;
};

declare module "@inertiajs/core" {
  interface InertiaConfig {
    sharedPageProps: SharedProps;
    errorValueType: string[];
  }
}

export type PageModule = {
  default: ComponentType & { layout?: (page: ReactElement) => ReactElement };
};
export type Issuer = {
  name: string;
  payable_to: string;
  treasurer: string;
  email: string;
  address: string;
  payment_instructions: string;
};
export type SeasonSettings = {
  id: number | null;
  year: number;
  issuer: Issuer;
  drive_folder_id: string | null;
  pdf_folder_id: string | null;
  spreadsheet_id: string | null;
  sheet_name: string;
  ledger_start_row: number;
};
export type SeasonForm = Omit<
  SeasonSettings,
  | "id"
  | "year"
  | "ledger_start_row"
  | "drive_folder_id"
  | "pdf_folder_id"
  | "spreadsheet_id"
> & {
  year: string;
  ledger_start_row: string;
  drive_folder_id: string;
  pdf_folder_id: string;
  spreadsheet_id: string;
};
export type InvoiceSummary = {
  id: number;
  number: string;
  recipient: string;
  description: string;
  issued_on: string;
  due_on: string | null;
  finalized_at: string | null;
  status: InvoiceStatus;
  total_cents: number;
  received_cents: number;
  owed_cents: number;
};
export type Official = {
  name: string;
  position?: string;
  fee_cents?: number;
  paid_cents?: number;
};
export type Pagination = {
  page: number;
  pages: number;
  total: number;
  from: number;
  to: number;
};
export type GameOptions = {
  games: GameSummary[];
  pagination: Pagination;
  query: string;
  filters: GameFilters;
  errors: string[];
};
export type GameFilters = Record<
  | "q"
  | "home_team"
  | "away_team"
  | "code"
  | "location"
  | "official"
  | "date_from"
  | "date_to"
  | "link_status",
  string
>;
export type GameSummary = {
  id: number;
  external_id: string;
  code: string | null;
  date: string;
  time: string | null;
  home_team: string | null;
  away_team: string | null;
  location: string | null;
  fees_cents: number;
  matchup: string;
  official_count: number;
  paid_by_team: string | null;
  invoices: { id: number; number: string; finalized_at: string | null }[];
  workbenches: { id: number; title: string }[];
};
export type ContactFields = Record<
  "name" | "organization" | "email" | "phone" | "address" | "notes",
  string
>;
export type ContactRecord = ContactFields & { id: number | null };
export type RecipientContact = Omit<ContactFields, "notes"> & {
  id: number;
  recipient: string;
  contact: string;
};
export type ContactOptions = {
  contacts: RecipientContact[];
  pagination: Pagination;
  query: string;
};
export type GameDetail = GameSummary & {
  officials: Official[];
  source: Record<string, string | null>[];
};
export type InvoiceDetail = Omit<
  InvoiceSummary,
  "id" | "recipient" | "description"
> & {
  recipient: string | null;
  description: string | null;
  id: number | null;
  year: number;
  issuer: Issuer;
  contact: string | null;
  recipient_address: string | null;
  public_notes: string | null;
  private_notes: string | null;
  publish_error: string | null;
  google_doc_id: string | null;
  google_pdf_id: string | null;
  ledger_row: number | null;
  line_items: {
    id: number | null;
    description: string | null;
    position: number;
    quantity: string;
    rate_cents: number | null;
    rate: string | null;
    total_cents: number;
  }[];
  game_ids: number[];
  games: GameSummary[];
  payments: {
    id: number;
    amount_cents: number;
    received_on: string;
    method: string;
    notes: string | null;
  }[];
};
export type InvoiceFields = Record<
  | "number"
  | "recipient"
  | "description"
  | "contact"
  | "recipient_address"
  | "issued_on"
  | "due_on"
  | "public_notes"
  | "private_notes",
  string
>;
export type EditableLineItem = {
  id?: number | null;
  key: string | number;
  description: string;
  quantity: string;
  rate: string;
  position: number;
  _destroy: boolean;
};
export type InvoiceForm = InvoiceFields & {
  game_ids: number[];
  line_items_attributes: EditableLineItem[];
};
export type DraftMetadata = {
  id: number;
  title: string;
  client_key: string;
  lock_version: number;
  updated_at: string;
  invoice_id: number | null;
  season_id: number;
};
export type InvoiceTotals = {
  invoiced: number;
  received: number;
  owed: number;
  outstanding: number;
  drafts: number;
};
export type ImportField =
  | "external_id"
  | "code"
  | "date"
  | "time"
  | "home_team"
  | "away_team"
  | "location"
  | "officials"
  | "fees";
export type OfficialColumn = {
  name?: string;
  amount?: string;
  position?: string;
};
export type ImportMapping = Partial<Record<ImportField, string>> & {
  official_columns?: Record<string, OfficialColumn>;
};
export type MappingForm = Record<ImportField, string> & {
  official_columns: Record<string, OfficialColumn>;
};
export type ImportInfo = { format?: string; skipped_meetings?: number };
export type ImportGame = Pick<
  GameSummary,
  "external_id" | "code" | "date" | "home_team" | "away_team" | "fees_cents"
> & { officials: Official[] };

export type SavedInvoice = InvoiceDetail & {
  id: number;
  recipient: string;
  description: string;
};
