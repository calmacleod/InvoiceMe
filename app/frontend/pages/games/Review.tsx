import Link from "../../components/AppLink";
import type { ImportGame } from "../../types";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../../styles/ui.stylex";
import { Head, useForm, usePage } from "@inertiajs/react";
import { Heading, Stat } from "../../components/UI";
import { money } from "../../lib/format";
export default function Review({
  games,
  total_count,
  errors_list,
  totals,
}: {
  games: ImportGame[];
  total_count: number;
  errors_list: string[];
  totals: { officials: number; fees: number };
}) {
  const form = useForm({});
  const { current_season: season } = usePage().props;
  if (!season) return null;
  return (
    <>
      <Head title="Review import" />
      <Heading eyebrow="IMPORT · STEP 3 OF 3" title="One last look">
        Review the game totals before saving to your {season.year} season.
      </Heading>
      {errors_list.length ? (
        <>
          <div {...stylex.props(ui.flash, ui.alert)} role="alert">
            <strong {...stylex.props(ui.strong)}>
              Fix these issues in the file before importing.
            </strong>
            <ul>
              {errors_list.map((error, i) => (
                <li key={i}>{error}</li>
              ))}
            </ul>
          </div>
          <Link {...stylex.props(ui.link, ui.button)} href="/games/new">
            Upload corrected file
          </Link>
        </>
      ) : (
        <div {...stylex.props(ui.stats)}>
          <Stat label="Games" value={total_count} />
          <Stat label="Officials / assignments" value={totals.officials} />
          <Stat label="Total official fees" value={money(totals.fees)} />
        </div>
      )}
      <section {...stylex.props(ui.card, ui.tableCard)}>
        <div {...stylex.props(ui.tableScroll)}>
          <table {...stylex.props(ui.table)}>
            <thead>
              <tr>
                <th {...stylex.props(ui.th)}>Game</th>
                <th {...stylex.props(ui.th)}>Code</th>
                <th {...stylex.props(ui.th)}>Date</th>
                <th {...stylex.props(ui.th)}>Matchup</th>
                <th {...stylex.props(ui.th)}>Officials</th>
                <th {...stylex.props(ui.th, ui.numeric)}>Fees</th>
              </tr>
            </thead>
            <tbody>
              {games.map((game) => (
                <tr key={game.external_id}>
                  <td {...stylex.props(ui.td)}>{game.external_id}</td>
                  <td {...stylex.props(ui.td)}>{game.code}</td>
                  <td {...stylex.props(ui.td)}>{game.date}</td>
                  <td {...stylex.props(ui.td)}>
                    {[game.away_team, game.home_team]
                      .filter(Boolean)
                      .join(" at ")}
                  </td>
                  <td {...stylex.props(ui.td)}>{game.officials.length}</td>
                  <td {...stylex.props(ui.td, ui.numeric)}>
                    {money(game.fees_cents)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div {...stylex.props(ui.tableBottom)}>
          Showing the first 100 games. All {total_count} games will be imported.
        </div>
      </section>
      {!errors_list.length && (
        <div {...stylex.props(ui.formActions)}>
          <Link {...stylex.props(ui.link, ui.button)} href="/games">
            Cancel
          </Link>
          <button
            {...stylex.props(ui.nativeButton, ui.button, ui.primary)}
            disabled={form.processing}
            onClick={() => form.post("/games/commit")}
          >
            Import {total_count} games →
          </button>
        </div>
      )}
    </>
  );
}
