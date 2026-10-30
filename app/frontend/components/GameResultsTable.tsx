import type { GameSummary } from "../types";
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
}: {
  games: GameSummary[];
  selectedIds?: number[];
  onToggle?: (id: number, checked: boolean) => void;
  invoiceId?: number | null;
  draftId?: number | null;
}) {
  const selected = new Set(selectedIds);
  return (
    <div {...stylex.props(ui.tableScroll)}>
      <table {...stylex.props(ui.table)}>
        <thead>
          <tr>
            {onToggle && <th {...stylex.props(ui.th)}>Select</th>}
            <th {...stylex.props(ui.th)}>Game / code</th>
            <th {...stylex.props(ui.th)}>Date</th>
            <th {...stylex.props(ui.th)}>Matchup / venue</th>
            <th {...stylex.props(ui.th)}>Officials & fees</th>
            <th {...stylex.props(ui.th, ui.numeric)}>Total fees</th>
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
