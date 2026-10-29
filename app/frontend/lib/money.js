export function scaled(value, places) {
  const text = String(value ?? "");
  if (!new RegExp(`^\\d+(?:\\.\\d{0,${places}})?$`).test(text)) return 0n;
  const [whole, fraction = ""] = text.split(".");
  return (
    BigInt(whole) * 10n ** BigInt(places) + BigInt(fraction.padEnd(places, "0"))
  );
}
export function lineTotal(quantity, rate) {
  return Number((scaled(quantity, 3) * scaled(rate, 2) + 500n) / 1000n);
}
export function invoiceTotal(items) {
  return items
    .filter((item) => !item._destroy)
    .reduce((sum, item) => sum + lineTotal(item.quantity, item.rate), 0);
}
