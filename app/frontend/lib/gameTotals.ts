import type { GameSummary } from "../types";

export function gameCountsByCode(
  selectedIds: number[],
  known: ReadonlyMap<number, Pick<GameSummary, "code">>,
) {
  const counts = new Map<string | null, number>();
  let unavailable = 0;
  for (const id of new Set(selectedIds)) {
    const game = known.get(id);
    if (!game) {
      unavailable += 1;
      continue;
    }
    const code = game.code?.trim() || null;
    counts.set(code, (counts.get(code) ?? 0) + 1);
  }
  return {
    byCode: [...counts]
      .map(([code, count]) => ({ code, count }))
      .sort((a, b) =>
        a.code === null
          ? 1
          : b.code === null
            ? -1
            : a.code.localeCompare(b.code),
      ),
    unavailable,
  };
}

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
