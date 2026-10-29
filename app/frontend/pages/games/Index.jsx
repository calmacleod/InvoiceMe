import { Head, Link } from "@inertiajs/react";
import { Heading, Search, date, money } from "../../components/UI";

export default function Index({ games, total_count, query }) {
  return (
    <>
      <Head title="Games & officials" />
      <Heading
        eyebrow="THE SEASON'S SOURCE OF TRUTH"
        title="Games & officials."
        actions={
          <Link href="/games/new" className="button primary">
            ↑ Import Horizon file
          </Link>
        }
      >
        Your Horizon master list, ready to connect to invoices.
      </Heading>
      <section className="card table-card">
        <div className="table-heading">
          <div>
            <h2>
              Master game list <span className="count">{total_count}</span>
            </h2>
            <p>
              Imported fees are reference amounts. Invoice rates remain yours to
              set.
            </p>
          </div>
          <Search url="/games" query={query} label="Search games" />
        </div>
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>Game / code</th>
                <th>Date</th>
                <th>Matchup / venue</th>
                <th>Officials</th>
                <th className="numeric">Official fees</th>
                <th>Invoices</th>
              </tr>
            </thead>
            <tbody>
              {games.map((game) => (
                <tr key={game.id}>
                  <td>
                    <strong>#{game.external_id}</strong>
                    <small>{game.code}</small>
                    {game.source[0]?.["Paid By Team"] && (
                      <small>
                        Paid by team: {game.source[0]["Paid By Team"]}
                      </small>
                    )}
                  </td>
                  <td className="nowrap">
                    {date(game.date)}
                    <small>{game.time}</small>
                  </td>
                  <td>
                    <strong>{game.matchup}</strong>
                    <small>{game.location}</small>
                  </td>
                  <td>
                    <details>
                      <summary>{game.official_count} officials</summary>
                      {game.officials.map((official, i) => (
                        <small key={i}>
                          {official.name} · {official.position}{" "}
                          {official.fee_cents != null ||
                          official.paid_cents != null
                            ? money(official.fee_cents ?? official.paid_cents)
                            : ""}
                        </small>
                      ))}
                    </details>
                    <details>
                      <summary>Source details</summary>
                      {game.source.map((source, index) => (
                        <dl className="source-details" key={index}>
                          {Object.entries(source).map(([key, value]) => (
                            <div key={key}>
                              <dt>{key}</dt>
                              <dd>{String(value ?? "")}</dd>
                            </div>
                          ))}
                        </dl>
                      ))}
                    </details>
                  </td>
                  <td className="numeric">{money(game.fees_cents)}</td>
                  <td>
                    {game.invoices.length
                      ? game.invoices.map((invoice) => (
                          <div key={invoice.id}>
                            <Link
                              href={`/invoices/${invoice.id}`}
                              className="small-link"
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
          <div className="empty">
            <span className="empty-icon">▦</span>
            <h2>{query ? "No matching games" : "Your games belong here"}</h2>
            <p>
              Download the master schedule or payroll CSV from Horizon and bring
              it in.
            </p>
            <Link href="/games/new" className="button primary">
              Import games →
            </Link>
          </div>
        )}
      </section>
    </>
  );
}
