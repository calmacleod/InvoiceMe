import { Head, useForm } from "@inertiajs/react";
import * as stylex from "@stylexjs/stylex";
import { useRef, useState, type FormEvent } from "react";
import Link from "../../components/AppLink";
import { Errors, Field, Heading, Section } from "../../components/UI";
import { money } from "../../lib/format";
import { scaled } from "../../lib/money";
import { ui } from "../../styles/ui.stylex";
import { styles } from "./expense.stylex";
import type { Expense } from "./types";

type Line = {
  key: string;
  id?: number;
  description: string;
  category: string;
  amount: string;
};

type Form = {
  lock_version: number;
  payee: string;
  description: string;
  category: string;
  incurred_on: string;
  amount: string;
  paid: boolean;
  paid_on: string;
  payment_method: string;
  cheque_number: string;
  reference: string;
  notes: string;
  line_items: Line[];
};

const decimal = (cents: number | null) =>
  cents === null ? "" : (cents / 100).toFixed(2);

function parseCents(value: string) {
  const text = value.trim();
  if (!/^-?\d+(?:\.\d{0,2})?$/.test(text)) return null;
  const unsigned = Number(scaled(text.replace(/^-/, ""), 2));
  return Number.isSafeInteger(unsigned)
    ? text.startsWith("-")
      ? -unsigned
      : unsigned
    : null;
}

export default function Edit({
  expense,
  season,
  categories,
}: {
  expense: Expense;
  season: { id: number; year: number };
  categories: string[];
}) {
  const form = useForm<Form>({
    lock_version: expense.lock_version,
    payee: expense.payee ?? "",
    description: expense.description ?? "",
    category: expense.category ?? "",
    incurred_on: expense.incurred_on ?? "",
    amount: decimal(expense.total_cents),
    paid: expense.paid,
    paid_on: expense.paid_on ?? "",
    payment_method: expense.payment_method ?? "",
    cheque_number: expense.cheque_number ?? "",
    reference: expense.reference ?? "",
    notes: expense.notes ?? "",
    line_items: expense.line_items.map((item) => ({
      key: `saved-${item.id}`,
      id: item.id,
      description: item.description,
      category: item.category ?? "",
      amount: decimal(item.amount_cents),
    })),
  });
  const deletion = useForm({});
  const [amountError, setAmountError] = useState("");
  const nextKey = useRef(0);
  const title = expense.id ? "Edit expense" : "New expense";
  const path = `/expenses?season_id=${season.id}`;
  const expenseUrl = `/expenses/${expense.id}`;
  const total = parseCents(form.data.amount);
  const itemized = form.data.line_items.reduce(
    (sum, line) => sum + (parseCents(line.amount) ?? 0),
    0,
  );
  const remainder = total === null ? null : total - itemized;

  function setLine(
    key: string,
    field: "description" | "category" | "amount",
    value: string,
  ) {
    form.setData(
      "line_items",
      form.data.line_items.map((line) =>
        line.key === key ? { ...line, [field]: value } : line,
      ),
    );
  }

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (
      total === null ||
      total <= 0 ||
      form.data.line_items.some((line) => parseCents(line.amount) === null)
    ) {
      setAmountError(
        "Enter a positive expense total and a valid dollar amount for every line.",
      );
      return;
    }
    if (itemized > total) {
      setAmountError(
        "The itemized amounts add up to more than the expense total.",
      );
      return;
    }
    setAmountError("");
    form.transform(({ amount, line_items, ...details }) => ({
      expense: {
        ...details,
        total_cents: parseCents(amount),
        line_items: line_items.map(
          ({ id, description, category, amount: itemAmount }) => ({
            id,
            description,
            category,
            amount_cents: parseCents(itemAmount),
          }),
        ),
      },
    }));
    if (expense.id) form.patch(expenseUrl);
    else form.post(path);
  }

  return (
    <>
      <Head title={title} />
      <Heading
        title={title}
        actions={
          <Link {...stylex.props(ui.link, ui.button)} href={path}>
            Back to expenses
          </Link>
        }
      >
        {season.year} expense register
      </Heading>
      <form onSubmit={submit}>
        <Errors errors={form.errors} />
        {amountError && (
          <p {...stylex.props(ui.flash, ui.alert)} role="alert">
            {amountError}
          </p>
        )}
        <datalist id="expense-categories">
          {categories.map((category) => (
            <option key={category} value={category} />
          ))}
        </datalist>
        <Section title="Expense details">
          <div {...stylex.props(ui.formGrid)}>
            <Field
              name="payee"
              label="Vendor or member"
              value={form.data.payee}
              onChange={(value) => form.setData("payee", value)}
              required
              maxLength={250}
            />
            <Field
              name="description"
              label="Description"
              value={form.data.description}
              onChange={(value) => form.setData("description", value)}
              required
              maxLength={250}
            />
            <Field
              name="incurred_on"
              label="Expense date"
              type="date"
              value={form.data.incurred_on}
              onChange={(value) => form.setData("incurred_on", value)}
              required
            />
            <Field
              name="amount"
              label="Full amount (CAD)"
              inputMode="decimal"
              value={form.data.amount}
              onChange={(value) => form.setData("amount", value)}
              required
            />
            <Field
              name="category"
              label="Category"
              list="expense-categories"
              value={form.data.category}
              onChange={(value) => form.setData("category", value)}
              required
              maxLength={100}
            />
            <Field
              name="reference"
              label="Receipt or invoice reference (optional)"
              value={form.data.reference}
              onChange={(value) => form.setData("reference", value)}
              maxLength={100}
            />
          </div>
          <Field
            name="notes"
            label="Notes (optional)"
            value={form.data.notes}
            onChange={(value) => form.setData("notes", value)}
            multiline
            rows={3}
            maxLength={5000}
          />
        </Section>
        <Section
          title="Itemized costs"
          hint="Leave a line’s category blank to use the expense category. Any unitemized amount uses the expense category."
        >
          {form.data.line_items.map((line, index) => (
            <div key={line.key} {...stylex.props(styles.item)}>
              <Field
                name={`line-description-${line.key}`}
                label={`Item ${index + 1} description`}
                value={line.description}
                onChange={(value) => setLine(line.key, "description", value)}
                required
                maxLength={250}
              />
              <Field
                name={`line-category-${line.key}`}
                label="Item category (optional)"
                list="expense-categories"
                placeholder={form.data.category || undefined}
                value={line.category}
                onChange={(value) => setLine(line.key, "category", value)}
                maxLength={100}
              />
              <Field
                name={`line-amount-${line.key}`}
                label="Item amount (CAD)"
                inputMode="decimal"
                value={line.amount}
                onChange={(value) => setLine(line.key, "amount", value)}
                required
              />
              <button
                type="button"
                {...stylex.props(ui.nativeButton, ui.button, ui.danger)}
                aria-label={`Remove item ${index + 1}`}
                onClick={() =>
                  form.setData(
                    "line_items",
                    form.data.line_items.filter(
                      (item) => item.key !== line.key,
                    ),
                  )
                }
              >
                Remove
              </button>
            </div>
          ))}
          <button
            type="button"
            {...stylex.props(ui.nativeButton, ui.button)}
            onClick={() => {
              const key = `new-${nextKey.current++}`;
              form.setData("line_items", [
                ...form.data.line_items,
                { key, description: "", category: "", amount: "" },
              ]);
            }}
          >
            + Add item
          </button>
          {!!form.data.line_items.length && (
            <div {...stylex.props(styles.total)} aria-live="polite">
              <strong>Itemized {money(itemized)}</strong>
              {remainder !== null &&
                (remainder < 0 ? (
                  <span {...stylex.props(ui.danger)}>
                    Over the full amount by {money(-remainder)}
                  </span>
                ) : (
                  <span>Unitemized {money(remainder)}</span>
                ))}
            </div>
          )}
        </Section>
        <Section title="Payment">
          <div {...stylex.props(styles.labelSpace)}>
            <label {...stylex.props(ui.checkbox)}>
              <input
                type="checkbox"
                checked={form.data.paid}
                onChange={(event) => {
                  const paid = event.target.checked;
                  form.setData({
                    ...form.data,
                    paid,
                    ...(paid
                      ? {}
                      : { paid_on: "", payment_method: "", cheque_number: "" }),
                  });
                }}
              />
              Paid
            </label>
          </div>
          {form.data.paid && (
            <div {...stylex.props(ui.formGrid)}>
              <Field
                name="paid_on"
                label="Date paid"
                type="date"
                value={form.data.paid_on}
                onChange={(value) => form.setData("paid_on", value)}
              />
              <Field
                name="payment_method"
                label="Payment method (optional)"
                value={form.data.payment_method}
                onChange={(value) => form.setData("payment_method", value)}
                maxLength={100}
              />
              <Field
                name="cheque_number"
                label="Cheque number (optional)"
                value={form.data.cheque_number}
                onChange={(value) => form.setData("cheque_number", value)}
                maxLength={100}
              />
            </div>
          )}
        </Section>
        <div {...stylex.props(ui.actions)}>
          <button
            {...stylex.props(ui.nativeButton, ui.button, ui.primary)}
            disabled={form.processing || deletion.processing}
          >
            {form.processing ? "Saving…" : "Save expense"}
          </button>
          {expense.id && (
            <button
              type="button"
              {...stylex.props(ui.nativeButton, ui.button, ui.danger)}
              disabled={deletion.processing || form.processing}
              onClick={() => {
                if (
                  window.confirm("Delete this expense and its itemized costs?")
                )
                  deletion.delete(expenseUrl);
              }}
            >
              Delete expense
            </button>
          )}
        </div>
      </form>
    </>
  );
}
