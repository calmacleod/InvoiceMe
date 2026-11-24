import { Head, router, useForm, usePage, usePoll } from "@inertiajs/react";
import * as stylex from "@stylexjs/stylex";
import { useEffect, useState } from "react";
import Link from "../../components/AppLink";
import {
  Badge,
  Field,
  Heading,
  PaginationControls,
  Stat,
} from "../../components/UI";
import { date, money } from "../../lib/format";
import { ui } from "../../styles/ui.stylex";
import type { Pagination } from "../../types";
import { styles } from "./expense.stylex";
import type { Expense, ExpenseSheet, ExpenseSummary } from "./types";

type Filters = { query?: string; category?: string; status?: string };

export default function Index({
  expenses,
  summary,
  pagination,
  categories,
  filters,
  sync,
}: {
  expenses: Expense[];
  summary: ExpenseSummary;
  pagination: Pagination;
  categories: string[];
  filters: Filters;
  sync: ExpenseSheet;
}) {
  const { current_season: season } = usePage().props;
  const syncForm = useForm({});
  const { start, stop } = usePoll(
    2000,
    { only: ["sync"] },
    { autoStart: false, background: "pause", mode: "rest" },
  );
  useEffect(() => {
    if (sync.active) start();
    else stop();
    return stop;
  }, [sync.active, start, stop]);

  if (!season) return null;
  const seasonQuery = `?season_id=${season.id}`;
  const status = sync.active
    ? "Updating Google Sheets…"
    : sync.error
      ? sync.error
      : sync.url
        ? sync.stale
          ? "There are changes to sync."
          : `Last synced ${date(sync.synced_at?.slice(0, 10))}.`
        : sync.ready
          ? "The first sync creates the spreadsheet in this year’s Financials folder."
          : !sync.folder_configured
            ? "Set this year’s Financials folder to sync."
            : "Connect the treasurer Google account to sync.";

  return (
    <>
      <Head title="Association expenses" />
      <Heading
        title="Association expenses"
        actions={
          <Link
            {...stylex.props(ui.link, ui.button, ui.primary)}
            href={`/expenses/new${seasonQuery}`}
          >
            + Add expense
          </Link>
        }
      >
        {season.year} expense register
      </Heading>
      <div {...stylex.props(ui.stats)}>
        <Stat label="Total expenses" value={money(summary.total_cents)} dark>
          {summary.count} {summary.count === 1 ? "expense" : "expenses"}
        </Stat>
        <Stat label="Paid" value={money(summary.paid_cents)} />
        <Stat label="Unpaid" value={money(summary.unpaid_cents)} />
      </div>
      <section {...stylex.props(ui.card, ui.connection)}>
        <div>
          <h2 {...stylex.props(ui.h2)}>Google Sheets</h2>
          <p
            role={sync.error ? "alert" : "status"}
            {...stylex.props(
              ui.paragraph,
              styles.status,
              !!sync.error && ui.danger,
            )}
          >
            {status}
          </p>
        </div>
        <div {...stylex.props(styles.controls)}>
          {sync.url && (
            <a
              {...stylex.props(ui.link, ui.button)}
              href={sync.url}
              target="_blank"
              rel="noreferrer"
            >
              Open spreadsheet ↗
            </a>
          )}
          {sync.ready ? (
            <button
              {...stylex.props(ui.nativeButton, ui.button)}
              disabled={sync.active || syncForm.processing}
              onClick={() => syncForm.post(`/expenses/sync${seasonQuery}`)}
            >
              Sync to Google Sheets
            </button>
          ) : (
            <Link
              {...stylex.props(ui.link, ui.button)}
              href={`/seasons/${season.id}/edit`}
            >
              Year &amp; settings
            </Link>
          )}
        </div>
      </section>
      <section {...stylex.props(ui.card, ui.tableCard)}>
        <div {...stylex.props(ui.tableHeading)}>
          <h2 {...stylex.props(ui.h2)}>Expenses</h2>
        </div>
        <ExpenseFilters
          key={JSON.stringify([season.id, filters])}
          seasonId={season.id}
          filters={filters}
          categories={categories}
          perPage={pagination.per_page}
        />
        {expenses.length ? (
          <div {...stylex.props(ui.tableScroll)}>
            <table {...stylex.props(ui.table)} aria-label="Expenses">
              <thead>
                <tr>
                  <th {...stylex.props(ui.th)}>Date</th>
                  <th {...stylex.props(ui.th)}>Expense</th>
                  <th {...stylex.props(ui.th)}>Category</th>
                  <th {...stylex.props(ui.th, ui.numeric)}>Total</th>
                  <th {...stylex.props(ui.th)}>Payment</th>
                  <th {...stylex.props(ui.th)}>Paid on</th>
                  <th {...stylex.props(ui.th)}>Cheque</th>
                </tr>
              </thead>
              <tbody>
                {expenses.map((expense) => (
                  <tr key={expense.id}>
                    <td {...stylex.props(ui.td)}>
                      {date(expense.incurred_on)}
                    </td>
                    <td {...stylex.props(ui.td)}>
                      <Link
                        {...stylex.props(ui.link, ui.strong)}
                        href={`/expenses/${expense.id}/edit${seasonQuery}`}
                      >
                        {expense.description}
                      </Link>
                      <div {...stylex.props(ui.muted)}>{expense.payee}</div>
                    </td>
                    <td {...stylex.props(ui.td)}>{expense.category}</td>
                    <td {...stylex.props(ui.td, ui.numeric)}>
                      {money(expense.total_cents)}
                    </td>
                    <td {...stylex.props(ui.td)}>
                      <Badge status={expense.paid ? "Paid" : "Outstanding"} />
                    </td>
                    <td {...stylex.props(ui.td)}>
                      {date(expense.paid_on) || "—"}
                    </td>
                    <td {...stylex.props(ui.td)}>
                      {expense.cheque_number || "—"}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div {...stylex.props(ui.tableHeading)}>
            <p {...stylex.props(ui.paragraph)}>
              {summary.count
                ? "No expenses match these filters."
                : "No expenses recorded for this year."}
            </p>
          </div>
        )}
        {pagination.total > 0 && (
          <PaginationControls
            pagination={pagination}
            url="/expenses"
            query=""
            filters={{ ...filters, season_id: String(season.id) }}
            only={["expenses", "pagination", "filters"]}
          />
        )}
      </section>
      {!!summary.by_category.length && (
        <section {...stylex.props(ui.card, ui.tableCard)}>
          <div {...stylex.props(ui.tableHeading)}>
            <h2 {...stylex.props(ui.h2)}>{season.year} totals by category</h2>
          </div>
          <div {...stylex.props(ui.tableScroll)}>
            <table
              {...stylex.props(ui.table)}
              aria-label="Year totals by category"
            >
              <thead>
                <tr>
                  <th {...stylex.props(ui.th)}>Category</th>
                  <th {...stylex.props(ui.th, ui.numeric)}>Total</th>
                  <th {...stylex.props(ui.th, ui.numeric)}>Paid</th>
                  <th {...stylex.props(ui.th, ui.numeric)}>Unpaid</th>
                </tr>
              </thead>
              <tbody>
                {summary.by_category.map((row) => (
                  <tr key={row.category}>
                    <td {...stylex.props(ui.td)}>{row.category}</td>
                    <td {...stylex.props(ui.td, ui.numeric)}>
                      {money(row.total_cents)}
                    </td>
                    <td {...stylex.props(ui.td, ui.numeric)}>
                      {money(row.paid_cents)}
                    </td>
                    <td {...stylex.props(ui.td, ui.numeric)}>
                      {money(row.unpaid_cents)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}
    </>
  );
}

function ExpenseFilters({
  filters,
  categories,
  seasonId,
  perPage,
}: {
  filters: Filters;
  categories: string[];
  seasonId: number;
  perPage: number;
}) {
  const [query, setQuery] = useState(filters.query ?? "");
  const [category, setCategory] = useState(filters.category ?? "");
  const [status, setStatus] = useState(filters.status ?? "");
  return (
    <form
      {...stylex.props(styles.filters)}
      onSubmit={(event) => {
        event.preventDefault();
        router.get(
          "/expenses",
          { season_id: seasonId, query, category, status, per_page: perPage },
          { preserveScroll: true, preserveState: true, replace: true },
        );
      }}
    >
      <Field
        name="query"
        label="Search expenses"
        type="search"
        value={query}
        onChange={setQuery}
      />
      <div>
        <label {...stylex.props(ui.label)} htmlFor="category-filter">
          Category
        </label>
        <select
          {...stylex.props(ui.input)}
          id="category-filter"
          value={category}
          onChange={(event) => setCategory(event.target.value)}
        >
          <option value="">All categories</option>
          {category && !categories.includes(category) && (
            <option value={category}>{category}</option>
          )}
          {categories.map((value) => (
            <option key={value}>{value}</option>
          ))}
        </select>
      </div>
      <div>
        <label {...stylex.props(ui.label)} htmlFor="payment-filter">
          Payment
        </label>
        <select
          {...stylex.props(ui.input)}
          id="payment-filter"
          value={status}
          onChange={(event) => setStatus(event.target.value)}
        >
          <option value="">Any status</option>
          <option value="paid">Paid</option>
          <option value="unpaid">Unpaid</option>
        </select>
      </div>
      <button {...stylex.props(ui.nativeButton, ui.button)}>
        Apply filters
      </button>
    </form>
  );
}
