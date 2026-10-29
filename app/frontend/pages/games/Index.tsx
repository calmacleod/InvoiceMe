import Link from "../../components/AppLink";
import type { GameDetail, GameSummary, Pagination } from "../../types";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../../styles/ui.stylex";
import { Head, router } from "@inertiajs/react";
import { Heading, Search, PaginationControls } from "../../components/UI";
import { date, money } from "../../lib/format";
import { useState } from "react";
import GameDetails from "../../components/GameDetails";
export default function Index({
  games,
  total_count,
  query,
  pagination,
  game_detail,
}: {
  games: GameSummary[];
  game_detail?: GameDetail;
  pagination: Pagination;
  total_count: number;
  query: string;
}) {
  const [expanded, setExpanded] = useState<number | null>(null);
  const [loading, setLoading] = useState(false);
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
          <Search
            url="/games"
            query={query}
            label="Search games"
            only={["games", "pagination", "query"]}
          />
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
                    {game.paid_by_team && (
                      <small {...stylex.props(ui.small)}>
                        Paid by team: {game.paid_by_team}
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
                    <button
                      type="button"
                      {...stylex.props(
                        ui.nativeButton,
                        ui.textButton,
                        ui.link,
                        ui.smallLink,
                      )}
                      aria-expanded={expanded === game.id}
                      onClick={() => {
                        if (expanded === game.id) {
                          setExpanded(null);
                          return;
                        }
                        setExpanded(game.id);
                        setLoading(true);
                        router.reload({
                          only: ["game_detail"],
                          data: { detail_id: game.id },
                          preserveUrl: true,
                          onFinish: () => setLoading(false),
                        });
                      }}
                    >
                      {game.official_count} officials · View details
                    </button>
                    {expanded === game.id &&
                      (game_detail?.id === game.id ? (
                        <GameDetails game={game_detail} />
                      ) : (
                        <p role="status">
                          {loading
                            ? "Loading details…"
                            : "Couldn't load details. Close and try again."}
                        </p>
                      ))}
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
        <PaginationControls
          pagination={pagination}
          url="/games"
          query={query}
          only={["games", "pagination", "query"]}
        />
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
