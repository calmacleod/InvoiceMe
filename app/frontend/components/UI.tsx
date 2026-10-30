import Link from "./AppLink";
import type {
  ReactNode,
  ChangeEvent,
  FormEvent,
  HTMLInputTypeAttribute,
} from "react";
import type { InvoiceStatus, Pagination } from "../types";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../styles/ui.stylex";
import { router } from "@inertiajs/react";
import { useState } from "react";
export function Heading({
  eyebrow,
  title,
  children,
  actions,
}: {
  eyebrow?: string;
  title: ReactNode;
  children?: ReactNode;
  actions?: ReactNode;
}) {
  return (
    <div {...stylex.props(ui.pageHeading)}>
      <div>
        {eyebrow && <span {...stylex.props(ui.eyebrow)}>{eyebrow}</span>}
        <h1 {...stylex.props(ui.h1)}>{title}</h1>
        <p {...stylex.props(ui.paragraph, ui.headingDescription)}>{children}</p>
      </div>
      {actions && <div {...stylex.props(ui.headingActions)}>{actions}</div>}
    </div>
  );
}
export function Section({
  step,
  title,
  children,
  hint,
}: {
  step?: string;
  title: string;
  children: ReactNode;
  hint?: string;
}) {
  return (
    <section {...stylex.props(ui.card)}>
      <div {...stylex.props(ui.sectionHeading)}>
        {step && <span {...stylex.props(ui.step)}>{step}</span>}
        <div>
          <h2 {...stylex.props(ui.h2)}>{title}</h2>
          {hint && (
            <p {...stylex.props(ui.paragraph, ui.sectionHint)}>{hint}</p>
          )}
        </div>
      </div>
      {children}
    </section>
  );
}
export type FieldProps = {
  label: string;
  name: string;
  value: string | number | null | undefined;
  onChange: (value: string) => void;
  type?: HTMLInputTypeAttribute;
  multiline?: boolean;
  rows?: number;
  required?: boolean;
  autoFocus?: boolean;
  autoComplete?: string;
  maxLength?: number;
  placeholder?: string;
  min?: string | number;
  max?: string | number;
  step?: string | number;
  disabled?: boolean;
};
export type FieldOptions = Omit<
  Partial<FieldProps>,
  "name" | "label" | "value" | "onChange"
>;
export function Field({
  label,
  name,
  value,
  onChange,
  type = "text",
  multiline = false,
  rows,
  ...props
}: FieldProps) {
  const common = {
    ...stylex.props(ui.input),
    id: name,
    name,
    value: value ?? "",
    onChange: (event: ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) =>
      onChange(event.target.value),
    onInput:
      type === "date"
        ? (event: FormEvent<HTMLInputElement | HTMLTextAreaElement>) =>
            onChange(event.currentTarget.value)
        : undefined,
    ...props,
  };
  return (
    <div>
      <label {...stylex.props(ui.label)} htmlFor={name}>
        {label}
      </label>
      {multiline ? (
        <textarea {...common} rows={rows} />
      ) : (
        <input {...common} type={type} />
      )}
    </div>
  );
}
export function Errors({
  errors = {},
}: {
  errors?: Record<string, string | string[] | undefined>;
}) {
  const messages = Object.entries(errors).flatMap(([key, value]) =>
    (Array.isArray(value) ? value : [value]).map(
      (message) =>
        `${key === "base" ? "" : `${key.replaceAll("_", " ")} `}${message}`,
    ),
  );
  return messages.length ? (
    <div {...stylex.props(ui.flash, ui.alert)} role="alert">
      <ul>
        {messages.map((message, i) => (
          <li key={i}>{message}</li>
        ))}
      </ul>
    </div>
  ) : null;
}
export function Badge({ status }: { status: InvoiceStatus }) {
  return (
    <span
      {...stylex.props(
        ui.badge,
        status === "Paid" && ui.badgePaid,
        status === "Outstanding" && ui.badgeOutstanding,
        status === "Part paid" && ui.badgePartPaid,
        status === "Needs sync" && ui.badgeNeedsSync,
      )}
    >
      {status}
    </span>
  );
}
export function Search({
  url,
  query,
  label,
  only,
  perPage,
}: {
  only?: string[];
  url: string;
  query: string;
  label: string;
  perPage?: number;
}) {
  const [value, setValue] = useState(query);
  return (
    <form
      {...stylex.props(ui.search)}
      onSubmit={(event) => {
        event.preventDefault();
        router.get(
          url,
          {
            q: value,
            per_page: perPage,
          },
          {
            only,
            preserveState: true,
            replace: true,
          },
        );
      }}
    >
      <input
        {...stylex.props(ui.input, ui.searchInput)}
        type="search"
        aria-label={label}
        placeholder={label}
        value={value}
        onChange={(event) => setValue(event.target.value)}
      />
      <button
        {...stylex.props(
          ui.nativeButton,
          ui.submit,
          ui.button,
          ui.searchButton,
        )}
      >
        Search
      </button>
    </form>
  );
}
export function Stat({
  label,
  value,
  children,
  dark = false,
}: {
  label: ReactNode;
  value: ReactNode;
  children?: ReactNode;
  dark?: boolean;
}) {
  return (
    <div {...stylex.props(ui.stat, dark && ui.statDark)}>
      <span {...stylex.props(ui.statLabel, dark && ui.statMutedOnDark)}>
        {label}
      </span>
      <strong {...stylex.props(ui.statValue)}>{value}</strong>
      <small
        {...stylex.props(ui.small, ui.statSmall, dark && ui.statMutedOnDark)}
      >
        {children}
      </small>
    </div>
  );
}

export function PaginationControls({
  pagination,
  url,
  query,
  only,
  filters = {},
  busy = false,
  onStart,
  onFinish,
}: {
  pagination: Pagination;
  url: string;
  query: string;
  only: string[];
  filters?: Record<string, string | string[]>;
  busy?: boolean;
  onStart?: () => void;
  onFinish?: () => void;
}) {
  return (
    <nav {...stylex.props(ui.tableBottom)} aria-label="Pagination">
      <span>
        {pagination.from}–{pagination.to} of {pagination.total}
      </span>
      <div {...stylex.props(ui.actions)}>
        <PageSizeSelect
          pagination={pagination}
          disabled={busy}
          onChange={(perPage) =>
            router.get(
              url,
              { ...filters, q: query, page: 1, per_page: perPage },
              {
                only,
                preserveState: true,
                preserveScroll: true,
                replace: true,
                onStart,
                onFinish,
              },
            )
          }
        />
        {pagination.page > 1 && (
          <Link
            {...stylex.props(ui.link, ui.button)}
            href={url}
            data={{
              ...filters,
              q: query,
              page: pagination.page - 1,
              per_page: pagination.per_page,
            }}
            only={only}
            preserveState
            preserveScroll
            aria-disabled={busy}
            onClick={(event) => {
              if (busy) event.preventDefault();
            }}
            onStart={onStart}
            onFinish={onFinish}
          >
            ← Previous
          </Link>
        )}
        <span>
          Page {pagination.page} of {pagination.pages}
        </span>
        {pagination.page < pagination.pages && (
          <Link
            {...stylex.props(ui.link, ui.button)}
            href={url}
            data={{
              ...filters,
              q: query,
              page: pagination.page + 1,
              per_page: pagination.per_page,
            }}
            only={only}
            preserveState
            preserveScroll
            aria-disabled={busy}
            onClick={(event) => {
              if (busy) event.preventDefault();
            }}
            onStart={onStart}
            onFinish={onFinish}
          >
            Next →
          </Link>
        )}
      </div>
    </nav>
  );
}

export function PageSizeSelect({
  pagination,
  onChange,
  disabled = false,
}: {
  pagination: Pick<Pagination, "per_page" | "per_page_options">;
  onChange: (value: number) => void;
  disabled?: boolean;
}) {
  return (
    <label {...stylex.props(ui.actions)}>
      Per page
      <select
        {...stylex.props(ui.input, ui.pageSize)}
        value={pagination.per_page}
        disabled={disabled}
        onChange={(event) => onChange(Number(event.target.value))}
      >
        {pagination.per_page_options.map((size) => (
          <option key={size} value={size}>
            {size}
          </option>
        ))}
      </select>
    </label>
  );
}
