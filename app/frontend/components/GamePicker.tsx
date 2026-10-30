import { memo, useEffect, useRef, useState } from "react";
import { router } from "@inertiajs/react";
import * as stylex from "@stylexjs/stylex";
import type {
  GameFilters as Filters,
  GameOptions,
  GameSummary,
  GameSort,
  GameSortColumn,
} from "../types";
import { ui } from "../styles/ui.stylex";
import { browserStyles as styles } from "./GameBrowser.stylex";
import { money } from "../lib/format";
import { gameCountsByCode, gameTotals } from "../lib/gameTotals";
import GameFilters from "./GameFilters";
import GameResultsTable from "./GameResultsTable";
import { PageSizeSelect } from "./UI";
import { sortGames, nextGameSort } from "../lib/gameSort";

export default memo(function GamePicker({
  options,
  initialSelected,
  selectedIds,
  onChange,
  invoiceId,
  draftId,
  invoiceTotal,
}: {
  options: GameOptions;
  initialSelected: GameSummary[];
  selectedIds: number[];
  onChange: (ids: number[]) => void;
  invoiceId: number | null;
  draftId: number | null;
  invoiceTotal: number;
}) {
  const [view, setView] = useState<"linked" | "all">(
    selectedIds.length ? "linked" : "all",
  );
  const [linkedPage, setLinkedPage] = useState(1);
  const [linkedPerPage, setLinkedPerPage] = useState(
    options.pagination.per_page,
  );
  const [loading, setLoading] = useState(false);
  const [failed, setFailed] = useState(false);
  const [linkingAll, setLinkingAll] = useState(false);
  const [bulkFailed, setBulkFailed] = useState(false);
  const [linkedSort, setLinkedSort] = useState<GameSort>(options.sort);
  const [expandedCode, setExpandedCode] = useState<string | null | undefined>(
    undefined,
  );
  const latestSelected = useRef(selectedIds);
  latestSelected.current = selectedIds;
  // Retain summaries across browser pages so off-page selections contribute
  // to the comparison immediately, before the autosave response returns.
  const known = useRef(new Map(initialSelected.map((game) => [game.id, game])));
  options.games.forEach((game) => known.current.set(game.id, game));
  const selected = sortGames(
    [...new Set(selectedIds)].flatMap((id) => {
      const game = known.current.get(id);
      return game ? [game] : [];
    }),
    linkedSort,
  );
  const expandedGames = selected.filter(
    (game) => (game.code?.trim() || null) === expandedCode,
  );
  const totals = gameTotals(selectedIds, known.current, invoiceTotal);
  const codeCounts = gameCountsByCode(selectedIds, known.current);
  const linkedPages = Math.max(1, Math.ceil(selected.length / linkedPerPage));
  const currentLinkedPage = Math.min(linkedPage, linkedPages);
  useEffect(() => {
    setLinkedPage((page) => Math.min(page, linkedPages));
  }, [linkedPages]);
  const pagination =
    view === "all"
      ? options.pagination
      : {
          page: currentLinkedPage,
          pages: linkedPages,
          total: selected.length,
          per_page: linkedPerPage,
          per_page_options: options.pagination.per_page_options,
          from: selected.length
            ? (currentLinkedPage - 1) * linkedPerPage + 1
            : 0,
          to: Math.min(currentLinkedPage * linkedPerPage, selected.length),
        };
  const games =
    view === "all"
      ? options.games
      : selected.slice(
          (currentLinkedPage - 1) * linkedPerPage,
          currentLinkedPage * linkedPerPage,
        );
  const load = (
    filters: Filters,
    page = 1,
    perPage = options.pagination.per_page,
    order = options.sort,
  ) => {
    setLoading(true);
    setFailed(false);
    router.reload({
      only: ["game_options"],
      data: {
        game_filters: { ...filters },
        game_page: page,
        game_per_page: perPage,
        game_sort: order.column,
        game_direction: order.direction,
      },
      preserveUrl: true,
      onError: () => setFailed(true),
      onNetworkError: () => setFailed(true),
      onHttpException: () => setFailed(true),
      onFinish: () => setLoading(false),
    });
  };
  const linkAllMatching = () => {
    setLinkingAll(true);
    setBulkFailed(false);
    const failed = () => setBulkFailed(true);
    router.reload({
      only: ["matching_games"],
      data: { game_filters: { ...options.filters } },
      preserveUrl: true,
      onSuccess: (page) => {
        const matches = page.props.matching_games as GameSummary[] | undefined;
        if (!Array.isArray(matches)) return failed();
        matches.forEach((game) => known.current.set(game.id, game));
        onChange([
          ...new Set([
            ...latestSelected.current,
            ...matches.map((game) => game.id),
          ]),
        ]);
      },
      onError: failed,
      onNetworkError: failed,
      onHttpException: failed,
      onFinish: () => setLinkingAll(false),
    });
  };
  const changeLinkedSort = (column: GameSortColumn) => {
    setLinkedSort(nextGameSort(linkedSort, column));
    setLinkedPage(1);
  };
  const sort = view === "all" ? options.sort : linkedSort;
  const changeSort = (column: GameSortColumn) => {
    const order = nextGameSort(sort, column);
    setLinkedSort(order);
    setLinkedPage(1);
    if (view === "all")
      load(options.filters, 1, options.pagination.per_page, order);
  };
  const toggle = (id: number, checked: boolean) =>
    onChange(
      checked
        ? [...new Set([...selectedIds, id])]
        : selectedIds.filter((value) => value !== id),
    );
  const changePage = (page: number) => {
    if (view === "linked") setLinkedPage(page);
    else load(options.filters, page);
  };
  const busy = (view === "all" && loading) || linkingAll;
  const difference = totals.differenceCents;
  return (
    <>
      <div {...stylex.props(styles.comparison)} aria-live="polite">
        <div {...stylex.props(styles.comparisonItem)}>
          <span {...stylex.props(ui.small)}>Invoice total</span>
          <strong {...stylex.props(styles.comparisonValue)}>
            {money(invoiceTotal)}
          </strong>
          <span {...stylex.props(ui.small)}>From your line items · CAD</span>
        </div>
        <div {...stylex.props(styles.comparisonItem)}>
          <span {...stylex.props(ui.small)}>Linked game fees</span>
          <strong {...stylex.props(styles.comparisonValue)}>
            {totals.feesCents === null
              ? "Unavailable"
              : money(totals.feesCents)}
          </strong>
          <span {...stylex.props(ui.small)}>
            {totals.count} {totals.count === 1 ? "game" : "games"} across all
            pages
          </span>
        </div>
        <div
          {...stylex.props(
            styles.comparisonItem,
            difference === 0 && styles.matched,
          )}
        >
          <span {...stylex.props(ui.small)}>Difference</span>
          <strong {...stylex.props(styles.comparisonValue)}>
            {difference === null
              ? "—"
              : `${difference > 0 ? "+" : difference < 0 ? "−" : ""}${money(Math.abs(difference))}`}
          </strong>
          <span {...stylex.props(ui.small)}>
            {difference === null
              ? totals.feesCents === null
                ? "Game fee total unavailable"
                : "Link games to compare totals"
              : difference === 0
                ? "Invoice and game fees match"
                : difference > 0
                  ? "Invoice is above game fees"
                  : "Game fees exceed the invoice"}
          </span>
        </div>
      </div>
      <p {...stylex.props(ui.paragraph, ui.hint)}>
        {totals.feesCents === null
          ? "Some linked games are unavailable. Reload this draft before comparing totals."
          : "Game fees include every linked game. A difference can include assigning, travel or other line items."}
      </p>
      {totals.count > 0 && (
        <section
          {...stylex.props(styles.codeSummary)}
          aria-label="Games by game code"
          aria-live="polite"
        >
          <h3 {...stylex.props(ui.h3)}>Games by game code</h3>
          <dl {...stylex.props(styles.comparison, styles.codeCounts)}>
            {codeCounts.byCode.map(({ code, count }) => (
              <div key={code ?? ""} {...stylex.props(styles.comparisonItem)}>
                <dt {...stylex.props(ui.small, styles.codeLabel)}>
                  <button
                    type="button"
                    {...stylex.props(ui.nativeButton, styles.codeButton)}
                    aria-expanded={expandedCode === code}
                    aria-controls="game-code-breakdown"
                    onClick={() =>
                      setExpandedCode(expandedCode === code ? undefined : code)
                    }
                  >
                    {code ?? "No game code"}{" "}
                    <span aria-hidden="true">
                      {expandedCode === code ? "▾" : "▸"}
                    </span>
                  </button>
                </dt>
                <dd {...stylex.props(styles.codeCount)}>
                  {count} {count === 1 ? "game" : "games"}
                </dd>
              </div>
            ))}
            {codeCounts.unavailable > 0 && (
              <div {...stylex.props(styles.comparisonItem)}>
                <dt {...stylex.props(ui.small)}>Unavailable games</dt>
                <dd {...stylex.props(styles.codeCount)}>
                  {codeCounts.unavailable}
                </dd>
              </div>
            )}
          </dl>
          {expandedCode !== undefined && (
            <section
              id="game-code-breakdown"
              aria-label={`Linked games for ${expandedCode ?? "No game code"}`}
            >
              <div {...stylex.props(ui.tableHeading)}>
                <h4 {...stylex.props(ui.h3)}>
                  {expandedCode ?? "No game code"} · {expandedGames.length}{" "}
                  {expandedGames.length === 1 ? "game" : "games"}
                </h4>
                <button
                  type="button"
                  {...stylex.props(ui.nativeButton, ui.textButton)}
                  onClick={() => setExpandedCode(undefined)}
                >
                  Close game breakdown
                </button>
              </div>
              <GameResultsTable
                games={expandedGames}
                selectedIds={selectedIds}
                onToggle={toggle}
                invoiceId={invoiceId}
                draftId={draftId}
                sort={linkedSort}
                onSort={changeLinkedSort}
                busy={busy}
              />
            </section>
          )}
        </section>
      )}
      <div
        {...stylex.props(styles.viewControls)}
        role="group"
        aria-label="Games shown"
      >
        <button
          type="button"
          {...stylex.props(
            ui.nativeButton,
            ui.button,
            view === "linked" && ui.primary,
          )}
          aria-pressed={view === "linked"}
          disabled={linkingAll}
          onClick={() => setView("linked")}
        >
          Linked games ({totals.count})
        </button>
        <button
          type="button"
          {...stylex.props(
            ui.nativeButton,
            ui.button,
            view === "all" && ui.primary,
          )}
          aria-pressed={view === "all"}
          disabled={linkingAll}
          onClick={() => setView("all")}
        >
          Browse all games
        </button>
      </div>
      {view === "all" && (
        <GameFilters
          collapsible
          id="picker"
          applied={options.filters}
          choices={options.filter_choices}
          errors={options.errors}
          busy={busy}
          onApply={(filters) => load(filters)}
        />
      )}
      <div {...stylex.props(ui.tableHeading)}>
        <span role="status">
          {busy
            ? "Finding games…"
            : `${pagination.total} ${view === "linked" ? "linked" : "matching"} ${pagination.total === 1 ? "game" : "games"}`}
        </span>
        {view === "all" && (
          <div {...stylex.props(ui.actions)}>
            <button
              type="button"
              {...stylex.props(ui.nativeButton, ui.button)}
              disabled={busy || !options.games.length}
              onClick={() =>
                onChange([
                  ...new Set([
                    ...selectedIds,
                    ...options.games.map((game) => game.id),
                  ]),
                ])
              }
            >
              Link this page
            </button>
            <button
              type="button"
              {...stylex.props(ui.nativeButton, ui.button, ui.primary)}
              disabled={busy || options.pagination.total === 0}
              onClick={linkAllMatching}
            >
              {linkingAll
                ? "Linking matching games…"
                : `Link all matching games (${options.pagination.total})`}
            </button>
          </div>
        )}
      </div>
      {view === "all" && failed && (
        <p {...stylex.props(ui.flash, ui.alert)} role="alert">
          Couldn't load games. Apply the filters again to retry.
        </p>
      )}
      {bulkFailed && (
        <p {...stylex.props(ui.flash, ui.alert)} role="alert">
          Couldn't link the matching games. Your existing selections are kept.
          Try linking all matching games again.
        </p>
      )}
      <GameResultsTable
        games={games}
        selectedIds={selectedIds}
        onToggle={toggle}
        invoiceId={invoiceId}
        draftId={draftId}
        sort={sort}
        onSort={changeSort}
        busy={busy}
      />
      {!games.length && (
        <p {...stylex.props(ui.empty)}>
          {view === "linked"
            ? "No games linked yet. Browse all games to add them to this draft."
            : "No matching games. Your linked games are kept when filters change."}
        </p>
      )}
      <nav
        {...stylex.props(ui.tableBottom)}
        aria-label={
          view === "linked"
            ? "Linked games pagination"
            : "Game browser pagination"
        }
      >
        <span>
          {pagination.from}–{pagination.to} of {pagination.total}
        </span>
        <div {...stylex.props(ui.actions)}>
          <PageSizeSelect
            pagination={pagination}
            disabled={busy}
            onChange={(size) => {
              if (view === "linked") {
                setLinkedPerPage(size);
                setLinkedPage(1);
              } else load(options.filters, 1, size);
            }}
          />
          <button
            type="button"
            {...stylex.props(ui.nativeButton, ui.button)}
            disabled={busy || pagination.page <= 1}
            onClick={() => changePage(pagination.page - 1)}
          >
            ← Previous
          </button>
          <span>
            Page {pagination.page} of {pagination.pages}
          </span>
          <button
            type="button"
            {...stylex.props(ui.nativeButton, ui.button)}
            disabled={busy || pagination.page >= pagination.pages}
            onClick={() => changePage(pagination.page + 1)}
          >
            Next →
          </button>
        </div>
      </nav>
    </>
  );
});
