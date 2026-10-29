import { Head, Link, useForm, usePage } from "@inertiajs/react";
import { Heading, Stat, money } from "../../components/UI";

export default function Review({ games, total_count, errors_list, totals }) {
  const form = useForm({});
  const { current_season: season } = usePage().props;
  return (
    <>
      <Head title="Review import" />
      <Heading eyebrow="IMPORT · STEP 3 OF 3" title="One last look">
        Review the game totals before saving to your {season.year} season.
      </Heading>
      {errors_list.length ? (
        <>
          <div className="flash alert" role="alert">
            <strong>Fix these issues in the file before importing.</strong>
            <ul>
              {errors_list.map((error, i) => (
                <li key={i}>{error}</li>
              ))}
            </ul>
          </div>
          <Link href="/games/new" className="button">
            Upload corrected file
          </Link>
        </>
      ) : (
        <div className="stats">
          <Stat label="Games" value={total_count} />
          <Stat label="Officials / assignments" value={totals.officials} />
          <Stat label="Total official fees" value={money(totals.fees)} />
        </div>
      )}
      <section className="card table-card">
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>Game</th>
                <th>Code</th>
                <th>Date</th>
                <th>Matchup</th>
                <th>Officials</th>
                <th className="numeric">Fees</th>
              </tr>
            </thead>
            <tbody>
              {games.map((game) => (
                <tr key={game.external_id}>
                  <td>{game.external_id}</td>
                  <td>{game.code}</td>
                  <td>{game.date}</td>
                  <td>
                    {[game.away_team, game.home_team]
                      .filter(Boolean)
                      .join(" at ")}
                  </td>
                  <td>{game.officials.length}</td>
                  <td className="numeric">{money(game.fees_cents)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div className="table-bottom">
          Showing the first 100 games. All {total_count} games will be imported.
        </div>
      </section>
      {!errors_list.length && (
        <div className="form-actions">
          <Link href="/games" className="button">
            Cancel
          </Link>
          <button
            className="button primary"
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
