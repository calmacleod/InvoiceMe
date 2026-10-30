import { memo, useEffect, useRef, useState } from "react";
import { router } from "@inertiajs/react";
import * as stylex from "@stylexjs/stylex";
import type {
  GameFilters as Filters,
  GameOptions,
  GameSummary,
} from "../types";
import { ui } from "../styles/ui.stylex";
import { browserStyles as styles } from "./GameBrowser.stylex";
import { money } from "../lib/format";
import { gameTotals } from "../lib/gameTotals";
import GameFilters from "./GameFilters";
import GameResultsTable from "./GameResultsTable";

const linkedPerPage = 25;

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
  const [loading, setLoading] = useState(false);
  const [failed, setFailed] = useState(false);
  // Retain summaries across browser pages so off-page selections contribute
  // to the comparison immediately, before the autosave response returns.
  const known = useRef(new Map(initialSelected.map((game) => [game.id, game])));
  options.games.forEach((game) => known.current.set(game.id, game));
  const selected = [...new Set(selectedIds)]
    .flatMap((id) => {
      const game = known.current.get(id);
      return game ? [game] : [];
    })
    .sort(
      (a, b) =>
        b.date.localeCompare(a.date) ||
        a.external_id.localeCompare(b.external_id),
    );
  const totals = gameTotals(selectedIds, known.current, invoiceTotal);
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
  const load = (filters: Filters, page = 1) => {
    setLoading(true);
    setFailed(false);
    router.reload({
      only: ["game_options"],
      data: { game_filters: { ...filters }, game_page: page },
      preserveUrl: true,
      onError: () => setFailed(true),
      onNetworkError: () => setFailed(true),
      onHttpException: () => setFailed(true),
      onFinish: () => setLoading(false),
    });
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
  const busy = view === "all" && loading;
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
          errors={options.errors}
          busy={loading}
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
          <button
            type="button"
            {...stylex.props(ui.nativeButton, ui.button)}
            disabled={loading || !options.games.length}
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
        )}
      </div>
      {view === "all" && failed && (
        <p {...stylex.props(ui.flash, ui.alert)} role="alert">
          Couldn't load games. Apply the filters again to retry.
        </p>
      )}
      <GameResultsTable
        games={games}
        selectedIds={selectedIds}
        onToggle={toggle}
        invoiceId={invoiceId}
        draftId={draftId}
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
