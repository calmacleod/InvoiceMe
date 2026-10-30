import type { GameDetail } from "../types";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../styles/ui.stylex";
import { money } from "../lib/format";
import { browserStyles as styles } from "./GameBrowser.stylex";

export default function GameDetails({ game }: { game: GameDetail }) {
  return (
    <div>
      <strong {...stylex.props(ui.strong)}>Crew fee breakdown</strong>
      <table {...stylex.props(styles.feeTable)}>
        <thead>
          <tr>
            <th {...stylex.props(styles.feeCell)}>Official</th>
            <th {...stylex.props(styles.feeCell)}>Position</th>
            <th {...stylex.props(styles.feeCell, ui.numeric)}>Fee</th>
          </tr>
        </thead>
        <tbody>
          {game.officials.map((official, index) => (
            <tr key={index}>
              <td {...stylex.props(styles.feeCell)}>{official.name}</td>
              <td {...stylex.props(styles.feeCell)}>
                {official.position || "—"}
              </td>
              <td {...stylex.props(styles.feeCell, ui.numeric)}>
                {official.fee_cents == null && official.paid_cents == null
                  ? "—"
                  : money(official.fee_cents ?? official.paid_cents)}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      {!game.officials.length && (
        <p {...stylex.props(ui.paragraph)}>
          No official assignments in the imported record.
        </p>
      )}
      <p {...stylex.props(ui.paragraph, ui.hint)}>
        Imported fees are reference amounts, not confirmation of payment.
      </p>
      <details {...stylex.props(ui.details)}>
        <summary {...stylex.props(ui.summary)}>Source details</summary>
        {game.source.map((source, index) => (
          <dl {...stylex.props(ui.sourceDetails)} key={index}>
            {Object.entries(source).map(([key, value]) => (
              <div key={key}>
                <dt>{key}</dt>
                <dd {...stylex.props(ui.sourceValue)}>{String(value ?? "")}</dd>
              </div>
            ))}
          </dl>
        ))}
      </details>
    </div>
  );
}
