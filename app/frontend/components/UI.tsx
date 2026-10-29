import type { ReactNode, ChangeEvent, HTMLInputTypeAttribute } from "react";
import type { InvoiceStatus } from "../types";
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
}: {
  url: string;
  query: string;
  label: string;
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
          },
          {
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
