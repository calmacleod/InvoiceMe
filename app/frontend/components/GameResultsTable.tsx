import type { GameSummary, GameSort, GameSortColumn } from "../types";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../styles/ui.stylex";
import { date, money } from "../lib/format";
import GameFeeDetails from "./GameFeeDetails";
import GameLinks from "./GameLinks";
import { browserStyles as styles } from "./GameBrowser.stylex";

export default function GameResultsTable({
  games,
  selectedIds = [],
  onToggle,
  invoiceId,
  draftId,
  sort,
  onSort,
  busy = false,
}: {
  games: GameSummary[];
  selectedIds?: number[];
  onToggle?: (id: number, checked: boolean) => void;
  invoiceId?: number | null;
  draftId?: number | null;
  sort?: GameSort;
  onSort?: (column: GameSortColumn) => void;
  busy?: boolean;
}) {
  const selected = new Set(selectedIds);
  const direction = (...columns: GameSortColumn[]) =>
    sort && columns.includes(sort.column)
      ? sort.direction === "asc"
        ? "ascending"
        : "descending"
      : undefined;
  const heading = (label: string, column: GameSortColumn) =>
    onSort ? (
      <button
        type="button"
        {...stylex.props(ui.nativeButton, styles.sortButton)}
        aria-label={`Sort by ${label.toLowerCase()}`}
        disabled={busy}
        onClick={() => onSort(column)}
      >
        {label}{" "}
        {sort?.column === column ? (sort.direction === "asc" ? "↑" : "↓") : "↕"}
      </button>
    ) : (
      label
    );
  return (
    <div {...stylex.props(ui.tableScroll)}>
      <table {...stylex.props(ui.table)}>
        <thead>
          <tr>
            {onToggle && <th {...stylex.props(ui.th)}>Select</th>}
            <th
              {...stylex.props(ui.th)}
              aria-sort={direction("external_id", "code")}
            >
              <div {...stylex.props(styles.sortHeading)}>
                {heading("Game", "external_id")} / {heading("Code", "code")}
              </div>
            </th>
            <th {...stylex.props(ui.th)} aria-sort={direction("date")}>
              {heading("Date", "date")}
            </th>
            <th
              {...stylex.props(ui.th)}
              aria-sort={direction("away_team", "home_team", "location")}
            >
              {onSort ? (
                <div {...stylex.props(styles.sortHeading)}>
                  {heading("Away team", "away_team")} /{" "}
                  {heading("Home team", "home_team")} /{" "}
                  {heading("Venue", "location")}
                </div>
              ) : (
                "Matchup / venue"
              )}
            </th>
            <th
              {...stylex.props(ui.th)}
              aria-sort={direction("official_count")}
            >
              {heading("Officials", "official_count")} & fees
            </th>
            <th
              {...stylex.props(ui.th, ui.numeric)}
              aria-sort={direction("fees_cents")}
            >
              {heading("Total fees", "fees_cents")}
            </th>
            <th {...stylex.props(ui.th)}>Invoice links</th>
          </tr>
        </thead>
        <tbody>
          {games.map((game) => (
            <tr key={game.id}>
              {onToggle && (
                <td {...stylex.props(ui.td, styles.gameCell)}>
                  <input
                    {...stylex.props(ui.checkbox)}
                    type="checkbox"
                    aria-label={`Select game ${game.external_id}`}
                    checked={selected.has(game.id)}
                    disabled={busy}
                    onChange={(event) =>
                      onToggle(game.id, event.target.checked)
                    }
                  />
                </td>
              )}
              <td {...stylex.props(ui.td, styles.gameCell)}>
                <strong {...stylex.props(ui.strong)}>
                  #{game.external_id}
                </strong>
                <small {...stylex.props(ui.small)}>{game.code}</small>
                {game.paid_by_team && (
                  <small {...stylex.props(ui.small)}>
                    Paid by team: {game.paid_by_team}
                  </small>
                )}
              </td>
              <td {...stylex.props(ui.td, styles.gameCell, ui.nowrap)}>
                {date(game.date)}
                <small {...stylex.props(ui.small)}>{game.time}</small>
              </td>
              <td {...stylex.props(ui.td, styles.gameCell)}>
                <strong {...stylex.props(ui.strong)}>{game.matchup}</strong>
                <small {...stylex.props(ui.small)}>{game.location}</small>
              </td>
              <td {...stylex.props(ui.td, styles.gameCell)}>
                <GameFeeDetails game={game} />
              </td>
              <td {...stylex.props(ui.td, styles.gameCell, ui.numeric)}>
                {money(game.fees_cents)}
              </td>
              <td {...stylex.props(ui.td, styles.gameCell)}>
                <GameLinks
                  game={game}
                  invoiceId={invoiceId}
                  draftId={draftId}
                  selected={selected.has(game.id)}
                />
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
