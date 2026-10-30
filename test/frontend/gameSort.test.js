import test from "node:test";
import assert from "node:assert/strict";
import { sortGames, nextGameSort } from "../../app/frontend/lib/gameSort.ts";

test("linked games support every master sort column in both directions without changing selections", () => {
  const alpha = {
    id: 1,
    external_id: "EXAMPLE-A",
    code: "example a",
    date: "2031-02-17",
    home_team: "Example Alpha",
    away_team: "Example Alpha",
    location: "Example Arena",
    official_count: 1,
    fees_cents: 1337,
  };
  const bravo = {
    id: 2,
    external_id: "EXAMPLE-B",
    code: "EXAMPLE B",
    date: "2031-02-18",
    home_team: "Example Bravo",
    away_team: "Example Bravo",
    location: "Example Field",
    official_count: 2,
    fees_cents: 2448,
  };
  const games = [bravo, alpha];
  for (const column of [
    "external_id",
    "code",
    "date",
    "home_team",
    "away_team",
    "location",
    "official_count",
    "fees_cents",
  ]) {
    assert.deepEqual(
      sortGames(games, { column, direction: "asc" }).map((game) => game.id),
      [1, 2],
      column,
    );
    assert.deepEqual(
      sortGames(games, { column, direction: "desc" }).map((game) => game.id),
      [2, 1],
      column,
    );
  }
  assert.deepEqual(games, [bravo, alpha]);
  assert.deepEqual(
    sortGames([bravo, { ...alpha, code: null }], {
      column: "code",
      direction: "asc",
    }).map((game) => game.id),
    [1, 2],
  );
  assert.deepEqual(
    sortGames([bravo, { ...alpha, fees_cents: bravo.fees_cents }], {
      column: "fees_cents",
      direction: "desc",
    }).map((game) => game.id),
    [1, 2],
  );
  assert.deepEqual(
    nextGameSort({ column: "date", direction: "desc" }, "fees_cents"),
    { column: "fees_cents", direction: "asc" },
  );
  assert.deepEqual(
    nextGameSort({ column: "fees_cents", direction: "asc" }, "fees_cents"),
    { column: "fees_cents", direction: "desc" },
  );
});
