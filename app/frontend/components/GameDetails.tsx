import type { GameDetail } from "../types";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../styles/ui.stylex";
import { money } from "../lib/format";

export default function GameDetails({ game }: { game: GameDetail }) {
  return (
    <div>
      {game.officials.map((official, index) => (
        <small {...stylex.props(ui.small)} key={index}>
          {official.name} · {official.position}{" "}
          {money(official.fee_cents ?? official.paid_cents)}
        </small>
      ))}
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
