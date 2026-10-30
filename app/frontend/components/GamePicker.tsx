import { memo, useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
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
import GameFilters from "./GameFilters";
import GameResultsTable from "./GameResultsTable";
import GameLinks from "./GameLinks";

export default memo(function GamePicker({
  options,
  initialSelected,
  selectedIds,
  onChange,
  invoiceId,
  draftId,
}: {
  options: GameOptions;
  initialSelected: GameSummary[];
  selectedIds: number[];
  onChange: (ids: number[]) => void;
  invoiceId: number | null;
  draftId: number | null;
}) {
  const [open, setOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [failed, setFailed] = useState(false);
  const dialog = useRef<HTMLDialogElement>(null);
  const known = useRef(new Map(initialSelected.map((game) => [game.id, game])));
  options.games.forEach((game) => known.current.set(game.id, game));
  const selected = selectedIds.flatMap((id) => {
    const game = known.current.get(id);
    return game ? [game] : [];
  });
  useEffect(() => {
    if (open && dialog.current && !dialog.current.open)
      dialog.current.showModal();
  }, [open]);
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
  return (
    <>
      <button
        type="button"
        {...stylex.props(ui.nativeButton, ui.button, ui.primary, ui.full)}
        onClick={() => setOpen(true)}
      >
        Browse & filter games
      </button>
      <p {...stylex.props(ui.paragraph, ui.hint)} role="status">
        {selectedIds.length} {selectedIds.length === 1 ? "game" : "games"}{" "}
        selected ·{" "}
        {money(selected.reduce((sum, game) => sum + game.fees_cents, 0))}{" "}
        reference fees
      </p>
      <div {...stylex.props(styles.selectedScroll)}>
        {selected.map((game) => (
          <div {...stylex.props(styles.selected)} key={game.id}>
            <div>
              <strong {...stylex.props(ui.strong)}>
                {game.code || game.external_id} · {game.date}
              </strong>
              <small {...stylex.props(ui.small)}>{game.matchup}</small>
              <small {...stylex.props(ui.small)}>
                {money(game.fees_cents)} · {game.official_count} officials
              </small>
              <GameLinks
                game={game}
                invoiceId={invoiceId}
                draftId={draftId}
                selected
              />
            </div>
            <button
              type="button"
              {...stylex.props(ui.nativeButton, ui.textButton, ui.danger)}
              aria-label={`Remove game ${game.external_id}`}
              onClick={() => toggle(game.id, false)}
            >
              ×
            </button>
          </div>
        ))}
      </div>
      {!selected.length && (
        <p {...stylex.props(ui.paragraph, ui.hint)}>
          Choose games using team, code, date and invoice-link filters. Your
          selection stays with the autosaved draft.
        </p>
      )}
      {open &&
        createPortal(
          <dialog
            ref={dialog}
            {...stylex.props(styles.dialog)}
            aria-labelledby="game-browser-title"
            onCancel={() => setOpen(false)}
            onClose={() => setOpen(false)}
          >
            <div {...stylex.props(styles.dialogHeader)}>
              <div>
                <h2 {...stylex.props(ui.h2)} id="game-browser-title">
                  Select Horizon games
                </h2>
                <p {...stylex.props(ui.paragraph)}>
                  Inspect each official's fee and existing invoice links before
                  selecting.
                </p>
              </div>
              <button
                type="button"
                {...stylex.props(ui.nativeButton, ui.button)}
                onClick={() => setOpen(false)}
              >
                Close game browser
              </button>
            </div>
            <GameFilters
              collapsible
              id="picker"
              applied={options.filters}
              errors={options.errors}
              busy={loading}
              onApply={(filters) => load(filters)}
            />
            <div {...stylex.props(ui.tableHeading)}>
              <span role="status">
                {loading
                  ? "Finding games…"
                  : `${options.pagination.total} matching ${options.pagination.total === 1 ? "game" : "games"}`}
              </span>
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
                Select this page
              </button>
            </div>
            {failed && (
              <p {...stylex.props(ui.flash, ui.alert)} role="alert">
                Couldn't load games. Apply the filters again to retry.
              </p>
            )}
            <GameResultsTable
              games={options.games}
              selectedIds={selectedIds}
              onToggle={toggle}
              invoiceId={invoiceId}
              draftId={draftId}
            />
            {!options.games.length && (
              <p {...stylex.props(ui.empty)}>
                No matching games. Your previously selected games are kept.
              </p>
            )}
            <div {...stylex.props(ui.tableBottom)}>
              <span>
                {options.pagination.from}–{options.pagination.to} of{" "}
                {options.pagination.total}
              </span>
              <div {...stylex.props(ui.actions)}>
                <button
                  type="button"
                  {...stylex.props(ui.nativeButton, ui.button)}
                  disabled={loading || options.pagination.page <= 1}
                  onClick={() =>
                    load(options.filters, options.pagination.page - 1)
                  }
                >
                  ← Previous
                </button>
                <span>
                  Page {options.pagination.page} of {options.pagination.pages}
                </span>
                <button
                  type="button"
                  {...stylex.props(ui.nativeButton, ui.button)}
                  disabled={
                    loading ||
                    options.pagination.page >= options.pagination.pages
                  }
                  onClick={() =>
                    load(options.filters, options.pagination.page + 1)
                  }
                >
                  Next →
                </button>
              </div>
            </div>
            <div {...stylex.props(styles.dialogFooter)}>
              <span>
                {selectedIds.length} selected · selections stay when filters
                change
              </span>
              <button
                type="button"
                {...stylex.props(ui.nativeButton, ui.button, ui.primary)}
                onClick={() => setOpen(false)}
              >
                Done selecting games
              </button>
            </div>
          </dialog>,
          document.body,
        )}
    </>
  );
});
