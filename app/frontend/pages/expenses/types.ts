export type ExpenseLineItem = {
  id: number;
  position: number;
  description: string;
  category: string | null;
  amount_cents: number;
};

export type Expense = {
  id: number | null;
  lock_version: number;
  payee: string | null;
  description: string | null;
  category: string | null;
  incurred_on: string | null;
  total_cents: number | null;
  paid: boolean;
  paid_on: string | null;
  payment_method: string | null;
  cheque_number: string | null;
  reference: string | null;
  notes: string | null;
  itemized_cents: number;
  remainder_cents: number;
  line_items: ExpenseLineItem[];
};

export type ExpenseSummary = {
  count: number;
  total_cents: number;
  paid_cents: number;
  unpaid_cents: number;
  by_category: {
    category: string;
    total_cents: number;
    paid_cents: number;
    unpaid_cents: number;
  }[];
};

export type ExpenseSheet = {
  status: "idle" | "queued" | "running" | "succeeded" | "failed";
  ready: boolean;
  folder_configured: boolean;
  active: boolean;
  stale: boolean;
  synced_at: string | null;
  url: string | null;
  error: string | null;
};
