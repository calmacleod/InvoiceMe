import type { GameDetail } from "../../types";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../../styles/ui.stylex";
import { Head, Link } from "@inertiajs/react";
import { Heading, Search } from "../../components/UI";
import { date, money } from "../../lib/format";
export default function Index({
  games,
  total_count,
  query,
}: {
  games: GameDetail[];
  total_count: number;
  query: string;
}) {
  return (
    <>
      <Head title="Games & officials" />
      <Heading
        eyebrow="THE SEASON'S SOURCE OF TRUTH"
        title="Games & officials."
        actions={
          <Link
            {...stylex.props(ui.link, ui.button, ui.primary)}
            href="/games/new"
          >
            ↑ Import Horizon file
          </Link>
        }
      >
        Your Horizon master list, ready to connect to invoices.
      </Heading>
      <section {...stylex.props(ui.card, ui.tableCard)}>
        <div {...stylex.props(ui.tableHeading)}>
          <div>
            <h2 {...stylex.props(ui.h2)}>
              Master game list{" "}
              <span {...stylex.props(ui.count)}>{total_count}</span>
            </h2>
            <p {...stylex.props(ui.paragraph)}>
              Imported fees are reference amounts. Invoice rates remain yours to
              set.
            </p>
          </div>
          <Search url="/games" query={query} label="Search games" />
        </div>
        <div {...stylex.props(ui.tableScroll)}>
          <table {...stylex.props(ui.table)}>
            <thead>
              <tr>
                <th {...stylex.props(ui.th)}>Game / code</th>
                <th {...stylex.props(ui.th)}>Date</th>
                <th {...stylex.props(ui.th)}>Matchup / venue</th>
                <th {...stylex.props(ui.th)}>Officials</th>
                <th {...stylex.props(ui.th, ui.numeric)}>Official fees</th>
                <th {...stylex.props(ui.th)}>Invoices</th>
              </tr>
            </thead>
            <tbody>
              {games.map((game) => (
                <tr key={game.id}>
                  <td {...stylex.props(ui.td)}>
                    <strong {...stylex.props(ui.strong)}>
                      #{game.external_id}
                    </strong>
                    <small {...stylex.props(ui.small)}>{game.code}</small>
                    {game.source[0]?.["Paid By Team"] && (
                      <small {...stylex.props(ui.small)}>
                        Paid by team: {game.source[0]["Paid By Team"]}
                      </small>
                    )}
                  </td>
                  <td {...stylex.props(ui.td, ui.nowrap)}>
                    {date(game.date)}
                    <small {...stylex.props(ui.small)}>{game.time}</small>
                  </td>
                  <td {...stylex.props(ui.td)}>
                    <strong {...stylex.props(ui.strong)}>{game.matchup}</strong>
                    <small {...stylex.props(ui.small)}>{game.location}</small>
                  </td>
                  <td {...stylex.props(ui.td)}>
                    <details {...stylex.props(ui.details)}>
                      <summary {...stylex.props(ui.summary)}>
                        {game.official_count} officials
                      </summary>
                      {game.officials.map((official, i) => (
                        <small {...stylex.props(ui.small)} key={i}>
                          {official.name} · {official.position}{" "}
                          {official.fee_cents != null ||
                          official.paid_cents != null
                            ? money(official.fee_cents ?? official.paid_cents)
                            : ""}
                        </small>
                      ))}
                    </details>
                    <details {...stylex.props(ui.details)}>
                      <summary {...stylex.props(ui.summary)}>
                        Source details
                      </summary>
                      {game.source.map((source, index) => (
                        <dl {...stylex.props(ui.sourceDetails)} key={index}>
                          {Object.entries(source).map(([key, value]) => (
                            <div key={key}>
                              <dt>{key}</dt>
                              <dd {...stylex.props(ui.sourceValue)}>
                                {String(value ?? "")}
                              </dd>
                            </div>
                          ))}
                        </dl>
                      ))}
                    </details>
                  </td>
                  <td {...stylex.props(ui.td, ui.numeric)}>
                    {money(game.fees_cents)}
                  </td>
                  <td {...stylex.props(ui.td)}>
                    {game.invoices.length
                      ? game.invoices.map((invoice) => (
                          <div key={invoice.id}>
                            <Link
                              {...stylex.props(ui.link, ui.smallLink)}
                              href={`/invoices/${invoice.id}`}
                            >
                              {invoice.number}
                            </Link>
                          </div>
                        ))
                      : "—"}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {!games.length && (
          <div {...stylex.props(ui.empty)}>
            <span {...stylex.props(ui.emptyIcon)}>▦</span>
            <h2 {...stylex.props(ui.h2)}>
              {query ? "No matching games" : "Your games belong here"}
            </h2>
            <p {...stylex.props(ui.paragraph)}>
              Download the master schedule or payroll CSV from Horizon and bring
              it in.
            </p>
            <Link
              {...stylex.props(ui.link, ui.button, ui.primary)}
              href="/games/new"
            >
              Import games →
            </Link>
          </div>
        )}
      </section>
    </>
  );
}
