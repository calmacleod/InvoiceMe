const currencyFormatter = new Intl.NumberFormat("en-CA", {
  style: "currency",
  currency: "CAD",
});
const dateFormatter = new Intl.DateTimeFormat("en-CA", {
  month: "short",
  day: "numeric",
  year: "numeric",
});
export const money = (cents: number | null | undefined) =>
  currencyFormatter.format(Number(cents || 0) / 100);
export const date = (value: string | null | undefined) =>
  value ? dateFormatter.format(new Date(`${value}T12:00:00`)) : "";
