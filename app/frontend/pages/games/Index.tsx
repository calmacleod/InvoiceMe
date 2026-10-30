import Link from "../../components/AppLink";
import type {
  GameSummary,
  Pagination,
  GameFilters as Filters,
  GameFilterChoices,
} from "../../types";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../../styles/ui.stylex";
import { Head, router } from "@inertiajs/react";
import { Heading, PaginationControls } from "../../components/UI";
import { useState } from "react";
import GameFilters from "../../components/GameFilters";
import GameResultsTable from "../../components/GameResultsTable";

const only = ["games", "pagination", "query", "filters", "filter_errors"];
export default function Index({
  games,
  total_count,
  query,
  pagination,
  filters,
  filter_choices,
  filter_errors,
}: {
  games: GameSummary[];
  pagination: Pagination;
  total_count: number;
  query: string;
  filters: Filters;
  filter_choices: GameFilterChoices;
  filter_errors: string[];
}) {
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
        Find the right games, inspect crew fees, and see where each game is
        linked.
      </Heading>
      <section {...stylex.props(ui.card, ui.tableCard)}>
        <div {...stylex.props(ui.tableHeading)}>
          <div>
            <h2 {...stylex.props(ui.h2)}>
              Master game list{" "}
              <span {...stylex.props(ui.count)}>{total_count}</span>
            </h2>
            <p {...stylex.props(ui.paragraph)}>
              Invoice links include saved invoices and your autosaved
              workbenches.
            </p>
          </div>
          <span role="status">
            {loading
              ? "Finding games…"
              : `${pagination.total} matching ${pagination.total === 1 ? "game" : "games"}`}
          </span>
        </div>
        <GameFilters
          id="master"
          applied={filters}
          choices={filter_choices}
          errors={filter_errors}
          busy={loading}
          onApply={(values) => {
            setLoading(true);
            router.get(
              "/games",
              { ...values, page: 1 },
              {
                only,
                preserveState: true,
                preserveScroll: true,
                replace: true,
                onFinish: () => setLoading(false),
              },
            );
          }}
        />
        <GameResultsTable games={games} />
        {!games.length && (
          <div {...stylex.props(ui.empty)}>
            <h2 {...stylex.props(ui.h2)}>No matching games</h2>
            <p {...stylex.props(ui.paragraph)}>
              Clear or adjust the filters, or import a Horizon file for this
              year.
            </p>
          </div>
        )}
        <PaginationControls
          pagination={pagination}
          url="/games"
          query={query}
          filters={filters}
          only={only}
        />
      </section>
    </>
  );
}
