export function scaled(
  value: string | number | null | undefined,
  places: number,
) {
  const text = String(value ?? "");
  if (!new RegExp(`^\\d+(?:\\.\\d{0,${places}})?$`).test(text)) return 0n;
  const [whole, fraction = ""] = text.split(".");
  return (
    BigInt(whole) * 10n ** BigInt(places) + BigInt(fraction.padEnd(places, "0"))
  );
}
export function lineTotal(quantity: string | number, rate: string | number) {
  return Number((scaled(quantity, 3) * scaled(rate, 2) + 500n) / 1000n);
}
export function invoiceTotal(
  items: {
    quantity: string | number;
    rate: string | number;
    _destroy?: boolean;
  }[],
) {
  return items
    .filter((item) => !item._destroy)
    .reduce((sum, item) => sum + lineTotal(item.quantity, item.rate), 0);
}
