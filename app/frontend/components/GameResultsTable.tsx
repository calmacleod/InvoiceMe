import { Menu } from "@base-ui/react/menu";
import type { GameSummary, GameSort, GameSortColumn } from "../types";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../styles/ui.stylex";
import { date, money } from "../lib/format";
import GameFeeDetails from "./GameFeeDetails";
import GameLinks from "./GameLinks";
import { browserStyles as styles } from "./GameBrowser.stylex";

const sortOptions: [string, GameSortColumn][] = [
  ["Game", "external_id"],
  ["Code", "code"],
  ["Date", "date"],
  ["Away team", "away_team"],
  ["Home team", "home_team"],
  ["Venue", "location"],
  ["Officials", "official_count"],
  ["Total fees", "fees_cents"],
];

export default function GameResultsTable({
  games,
  selectedIds = [],
  onToggle,
  onTogglePage,
  selectionContext = "draft",
  invoiceId,
  draftId,
  sort,
  onSort,
  busy = false,
}: {
  games: GameSummary[];
  selectedIds?: number[];
  onToggle?: (id: number, checked: boolean) => void;
  onTogglePage?: (checked: boolean) => void;
  selectionContext?: "draft" | "bulk" | "group";
  invoiceId?: number | null;
  draftId?: number | null;
  sort?: GameSort;
  onSort?: (column: GameSortColumn) => void;
  busy?: boolean;
}) {
  const selected = new Set(selectedIds);
  const allSelected =
    games.length > 0 && games.every((game) => selected.has(game.id));
  const partiallySelected =
    !allSelected && games.some((game) => selected.has(game.id));
  const direction = (...columns: GameSortColumn[]) =>
    sort && columns.includes(sort.column)
      ? sort.direction === "asc"
        ? "ascending"
        : "descending"
      : undefined;
  const arrow = sort?.direction === "desc" ? "↓" : "↑";

  const heading = (label: string, column: GameSortColumn) =>
    onSort ? (
      <button
        type="button"
        {...stylex.props(ui.nativeButton, styles.sortButton)}
        aria-label={`Sort by ${label.toLowerCase()}`}
        disabled={busy}
        onClick={() => onSort(column)}
      >
        {label} {sort?.column === column ? arrow : "↕"}
      </button>
    ) : (
      label
    );

  return (
    <>
      {onSort && (
        <div {...stylex.props(styles.compactSort)}>
          <Menu.Root>
            <Menu.Trigger
              disabled={busy}
              {...stylex.props(ui.nativeButton, ui.button)}
            >
              Sort by{" "}
              {sortOptions
                .find(([, column]) => sort?.column === column)?.[0]
                .toLowerCase() ?? "game"}{" "}
              {arrow}
            </Menu.Trigger>
            <Menu.Portal>
              <Menu.Positioner
                align="end"
                sideOffset={5}
                {...stylex.props(styles.sortPositioner)}
              >
                <Menu.Popup {...stylex.props(styles.sortMenu)}>
                  {sortOptions.map(([label, column]) => (
                    <Menu.Item
                      key={column}
                      className={({ highlighted }) =>
                        stylex.props(
                          styles.sortMenuItem,
                          highlighted && styles.sortHighlight,
                        ).className
                      }
                      onClick={() => onSort(column)}
                    >
                      {label}
                      {sort?.column === column ? ` ${arrow}` : ""}
                    </Menu.Item>
                  ))}
                </Menu.Popup>
              </Menu.Positioner>
            </Menu.Portal>
          </Menu.Root>
        </div>
      )}
      <div {...stylex.props(ui.tableScroll)}>
        <table {...stylex.props(ui.table, styles.gameTable)}>
          <thead>
            <tr>
              {onToggle && (
                <th
                  scope="col"
                  {...stylex.props(ui.th, styles.selectionColumn)}
                >
                  {onTogglePage ? (
                    <input
                      {...stylex.props(ui.checkbox)}
                      type="checkbox"
                      aria-label="Select all games on this page"
                      disabled={busy || !games.length}
                      checked={allSelected}
                      ref={(input) => {
                        if (input) input.indeterminate = partiallySelected;
                      }}
                      onChange={(event) => onTogglePage(event.target.checked)}
                    />
                  ) : (
                    <span {...stylex.props(ui.srOnly)}>Select</span>
                  )}
                </th>
              )}
              <th
                scope="col"
                {...stylex.props(ui.th, styles.gameColumn)}
                aria-sort={direction("external_id", "code")}
              >
                <div {...stylex.props(styles.sortHeading, styles.gameWide)}>
                  {heading("Game", "external_id")} / {heading("Code", "code")}
                </div>
                <span {...stylex.props(styles.gameNarrow)}>Game</span>
              </th>
              <th
                scope="col"
                {...stylex.props(ui.th, styles.gameDateColumn, styles.gameWide)}
                aria-sort={direction("date")}
              >
                {heading("Date", "date")}
              </th>
              <th
                scope="col"
                {...stylex.props(ui.th, styles.gameWide)}
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
                scope="col"
                {...stylex.props(ui.th, ui.numeric, styles.gameFeesColumn)}
                aria-sort={direction("fees_cents", "official_count")}
              >
                <div {...stylex.props(styles.gameWide)}>
                  {heading("Total fees", "fees_cents")}
                  <br />
                  {heading("Officials", "official_count")}
                </div>
                <span {...stylex.props(styles.gameNarrow)}>Fees</span>
              </th>
              <th
                scope="col"
                {...stylex.props(
                  ui.th,
                  styles.gameLinksColumn,
                  styles.gameWide,
                )}
              >
                Invoice links
              </th>
            </tr>
          </thead>
          <tbody>
            {games.map((game) => {
              const links = (
                <GameLinks
                  game={game}
                  invoiceId={invoiceId}
                  draftId={draftId}
                  selected={
                    selectionContext !== "bulk" && selected.has(game.id)
                  }
                  groupSelection={selectionContext === "group"}
                />
              );
              return (
                <tr key={game.id} {...stylex.props(ui.row)}>
                  {onToggle && (
                    <td
                      {...stylex.props(
                        ui.td,
                        styles.gameCell,
                        styles.selectionColumn,
                      )}
                    >
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
                  <td
                    {...stylex.props(
                      ui.td,
                      styles.gameCell,
                      styles.gameOverflow,
                    )}
                  >
                    <strong {...stylex.props(ui.strong)}>
                      #{game.external_id}
                    </strong>
                    {game.code && (
                      <small {...stylex.props(ui.small)}>{game.code}</small>
                    )}
                    {game.horizon_cancelled && (
                      <small {...stylex.props(ui.small)}>
                        Horizon cancelled: {game.horizon_cancelled}
                      </small>
                    )}
                    {game.paid_by_team && (
                      <small {...stylex.props(ui.small)}>
                        Paid by team: {game.paid_by_team}
                      </small>
                    )}
                    <div {...stylex.props(styles.gameNarrow)}>
                      <strong {...stylex.props(ui.strong)}>
                        {game.matchup}
                      </strong>
                      <small {...stylex.props(ui.small)}>
                        {[date(game.date), game.time, game.location]
                          .filter(Boolean)
                          .join(" · ")}
                      </small>
                      {links}
                    </div>
                  </td>
                  <td
                    {...stylex.props(ui.td, styles.gameCell, styles.gameWide)}
                  >
                    {date(game.date)}
                    <small {...stylex.props(ui.small)}>{game.time}</small>
                  </td>
                  <td
                    {...stylex.props(
                      ui.td,
                      styles.gameCell,
                      styles.gameWide,
                      styles.gameOverflow,
                    )}
                  >
                    <strong {...stylex.props(ui.strong)}>{game.matchup}</strong>
                    <small {...stylex.props(ui.small)}>{game.location}</small>
                  </td>
                  <td {...stylex.props(ui.td, styles.gameCell, ui.numeric)}>
                    <strong {...stylex.props(ui.strong, ui.nowrap)}>
                      {money(game.fees_cents)}
                    </strong>
                    <div>
                      <GameFeeDetails game={game} />
                    </div>
                  </td>
                  <td
                    {...stylex.props(ui.td, styles.gameCell, styles.gameWide)}
                  >
                    {links}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </>
  );
}
