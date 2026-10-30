import type { GameSort, GameSortColumn, GameSummary } from "../types";

function compare(a: string | number | null, b: string | number | null): number {
  if (a === b) return 0;
  if (a === null) return -1;
  if (b === null) return 1;
  const left =
    typeof a === "string"
      ? a.replace(/[A-Z]/g, (letter) => letter.toLowerCase())
      : a;
  const right =
    typeof b === "string"
      ? b.replace(/[A-Z]/g, (letter) => letter.toLowerCase())
      : b;
  return left < right ? -1 : left > right ? 1 : 0;
}

export function sortGames(games: GameSummary[], order: GameSort) {
  return [...games].sort(
    (a, b) =>
      compare(a[order.column], b[order.column]) *
        (order.direction === "asc" ? 1 : -1) ||
      compare(a.external_id, b.external_id) ||
      a.id - b.id,
  );
}

export function nextGameSort(sort: GameSort, column: GameSortColumn): GameSort {
  return {
    column,
    direction:
      sort.column === column && sort.direction === "asc" ? "desc" : "asc",
  };
}
