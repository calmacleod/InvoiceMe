import type { GameSummary } from "../types";

export function gameTotals(
  selectedIds: number[],
  known: ReadonlyMap<number, Pick<GameSummary, "fees_cents">>,
  invoiceCents: number,
) {
  const ids = [...new Set(selectedIds)];
  let fees = 0;
  let complete = true;
  for (const id of ids) {
    const game = known.get(id);
    if (game) fees += game.fees_cents;
    else complete = false;
  }
  return {
    count: ids.length,
    feesCents: complete ? fees : null,
    differenceCents: complete && ids.length > 0 ? invoiceCents - fees : null,
  };
}
