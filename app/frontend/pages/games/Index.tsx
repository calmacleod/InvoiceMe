import Link from "../../components/AppLink";
import type {
  GameSummary,
  Pagination,
  GameFilters as Filters,
  GameFilterChoices,
  GameSort,
} from "../../types";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../../styles/ui.stylex";
import { Head, router, usePage } from "@inertiajs/react";
import { Heading, PaginationControls } from "../../components/UI";
import { useEffect, useState } from "react";
import GameFilters from "../../components/GameFilters";
import GameResultsTable from "../../components/GameResultsTable";
import { browserStyles as styles } from "../../components/GameBrowser.stylex";

const only = [
  "games",
  "pagination",
  "query",
  "filters",
  "filter_errors",
  "sort",
  "flash",
];
export default function Index({
  games,
  total_count,
  query,
  pagination,
  filters,
  filter_choices,
  filter_errors,
  sort,
}: {
  games: GameSummary[];
  pagination: Pagination;
  total_count: number;
  query: string;
  filters: Filters;
  filter_choices: GameFilterChoices;
  filter_errors: string[];
  sort: GameSort;
}) {
  const [loading, setLoading] = useState(false);
  const { current_season: season } = usePage().props;
  const [selectedIds, setSelectedIds] = useState<number[]>([]);
  const [bulkError, setBulkError] = useState("");
  useEffect(() => setSelectedIds([]), [season?.id]);
  const load = (values: Filters, order = sort) => {
    setLoading(true);
    router.patch(
      "/games/filters",
      {
        ...values,
        season_id: season!.id,
        sort: order.column,
        direction: order.direction,
        per_page: pagination.per_page,
        page: 1,
      },
      {
        only,
        preserveState: true,
        preserveScroll: true,
        replace: true,
        onSuccess: () => router.flushAll(),
        onFinish: () => setLoading(false),
      },
    );
  };
  const selectAllMatching = () => {
    setLoading(true);
    setBulkError("");
    const failed = () =>
      setBulkError("Couldn't select the matching games. Please retry.");
    router.reload({
      only: ["matching_game_ids"],
      data: { ...filters, season_id: season!.id },
      preserveUrl: true,
      onSuccess: (page) => {
        const ids = page.props.matching_game_ids as number[] | undefined;
        if (!Array.isArray(ids)) return failed();
        setSelectedIds((previous) => [...new Set([...previous, ...ids])]);
      },
      onError: failed,
      onNetworkError: failed,
      onHttpException: failed,
      onFinish: () => setLoading(false),
    });
  };
  const markInvoiced = (value: boolean) => {
    setLoading(true);
    setBulkError("");
    const failed = () =>
      setBulkError(
        "Couldn't update the selected games. Your selection is kept; please retry.",
      );
    router.patch(
      "/games/invoicing_status",
      {
        ...filters,
        game_ids: selectedIds,
        already_invoiced: value,
        season_id: season!.id,
        sort: sort.column,
        direction: sort.direction,
        per_page: pagination.per_page,
        page: pagination.page,
      },
      {
        only,
        preserveState: true,
        preserveScroll: true,
        replace: true,
        onSuccess: () => {
          setSelectedIds([]);
          router.flushAll();
        },
        onError: failed,
        onNetworkError: failed,
        onHttpException: failed,
        onFinish: () => setLoading(false),
      },
    );
  };
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
            setSelectedIds([]);
            load(values);
          }}
        />
        <div
          {...stylex.props(styles.bulkActions)}
          role="group"
          aria-label="Bulk game actions"
        >
          <span role="status">
            {selectedIds.length} {selectedIds.length === 1 ? "game" : "games"}{" "}
            selected across pages
          </span>
          <button
            type="button"
            {...stylex.props(ui.nativeButton, ui.button)}
            disabled={loading || pagination.total === 0}
            onClick={selectAllMatching}
          >
            Select all matching games ({pagination.total})
          </button>
          <button
            type="button"
            {...stylex.props(ui.nativeButton, ui.button, ui.primary)}
            disabled={loading || selectedIds.length === 0}
            onClick={() => markInvoiced(true)}
          >
            Mark as already invoiced
          </button>
          <button
            type="button"
            {...stylex.props(ui.nativeButton, ui.button)}
            disabled={loading || selectedIds.length === 0}
            onClick={() => markInvoiced(false)}
          >
            Clear manual invoiced mark
          </button>
          <button
            type="button"
            {...stylex.props(ui.nativeButton, ui.textButton)}
            disabled={loading || selectedIds.length === 0}
            onClick={() => setSelectedIds([])}
          >
            Clear game selection
          </button>
        </div>
        {bulkError && (
          <p {...stylex.props(ui.flash, ui.alert)} role="alert">
            {bulkError}
          </p>
        )}
        <GameResultsTable
          games={games}
          selectedIds={selectedIds}
          selectionContext="bulk"
          onToggle={(id, checked) =>
            setSelectedIds((previous) =>
              checked
                ? [...new Set([...previous, id])]
                : previous.filter((value) => value !== id),
            )
          }
          onTogglePage={(checked) =>
            setSelectedIds((previous) =>
              checked
                ? [...new Set([...previous, ...games.map((game) => game.id)])]
                : previous.filter(
                    (id) => !games.some((game) => game.id === id),
                  ),
            )
          }
          sort={sort}
          busy={loading}
          onSort={(column) =>
            load(filters, {
              column,
              direction:
                sort.column === column && sort.direction === "asc"
                  ? "desc"
                  : "asc",
            })
          }
        />
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
          filters={{
            ...filters,
            season_id: String(season!.id),
            sort: sort.column,
            direction: sort.direction,
          }}
          only={only}
          busy={loading}
          onStart={() => setLoading(true)}
          onFinish={() => setLoading(false)}
        />
      </section>
    </>
  );
}
