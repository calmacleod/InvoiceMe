import { router } from "@inertiajs/react";
import { useState } from "react";

export const money = (cents) =>
  new Intl.NumberFormat("en-CA", { style: "currency", currency: "CAD" }).format(
    Number(cents || 0) / 100,
  );
export const date = (value) =>
  value
    ? new Intl.DateTimeFormat("en-CA", {
        month: "short",
        day: "numeric",
        year: "numeric",
      }).format(new Date(`${value}T12:00:00`))
    : "";
export function Heading({ eyebrow, title, children, actions }) {
  return (
    <div className="page-heading">
      <div>
        {eyebrow && <span className="eyebrow">{eyebrow}</span>}
        <h1>{title}</h1>
        <p>{children}</p>
      </div>
      {actions}
    </div>
  );
}
export function Section({ step, title, children, hint }) {
  return (
    <section className="card">
      <div className="section-heading">
        {step && <span className="step">{step}</span>}
        <div>
          <h2>{title}</h2>
          {hint && <p>{hint}</p>}
        </div>
      </div>
      {children}
    </section>
  );
}
export function Field({
  label,
  name,
  value,
  onChange,
  type = "text",
  multiline = false,
  ...props
}) {
  const Input = multiline ? "textarea" : "input";
  return (
    <div>
      <label htmlFor={name}>{label}</label>
      <Input
        id={name}
        name={name}
        type={multiline ? undefined : type}
        value={value ?? ""}
        onChange={(event) => onChange(event.target.value)}
        {...props}
      />
    </div>
  );
}
export function Errors({ errors = {} }) {
  const messages = Object.entries(errors).flatMap(([key, value]) =>
    (Array.isArray(value) ? value : [value]).map(
      (message) =>
        `${key === "base" ? "" : `${key.replaceAll("_", " ")} `}${message}`,
    ),
  );
  return messages.length ? (
    <div role="alert" className="flash alert">
      <ul>
        {messages.map((message, i) => (
          <li key={i}>{message}</li>
        ))}
      </ul>
    </div>
  ) : null;
}
export function Badge({ status }) {
  return (
    <span className={`badge ${status.toLowerCase().replaceAll(" ", "-")}`}>
      {status}
    </span>
  );
}
export function Search({ url, query, label }) {
  const [value, setValue] = useState(query);
  return (
    <form
      className="search"
      onSubmit={(event) => {
        event.preventDefault();
        router.get(url, { q: value }, { preserveState: true, replace: true });
      }}
    >
      <input
        type="search"
        aria-label={label}
        placeholder={label}
        value={value}
        onChange={(event) => setValue(event.target.value)}
      />
      <button className="button">Search</button>
    </form>
  );
}
export function Stat({ label, value, children, dark = false }) {
  return (
    <div className={`stat${dark ? " dark" : ""}`}>
      <span>{label}</span>
      <strong>{value}</strong>
      <small>{children}</small>
    </div>
  );
}
