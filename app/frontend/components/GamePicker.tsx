import { memo, useRef, useState } from "react";
import { router } from "@inertiajs/react";
import * as stylex from "@stylexjs/stylex";
import type { GameOptions, GameSummary } from "../types";
import { ui } from "../styles/ui.stylex";
import { money } from "../lib/format";

// Typing invoice fields does not re-render the game list. Search and pagination
// request only game_options, preserving the unsaved Inertia form and selection.
export default memo(function GamePicker({
  options,
  initialSelected,
  selectedIds,
  onChange,
  invoiceId,
}: {
  options: GameOptions;
  initialSelected: GameSummary[];
  selectedIds: number[];
  onChange: (ids: number[]) => void;
  invoiceId: number | null;
}) {
  const [query, setQuery] = useState(options.query);
  const [loading, setLoading] = useState(false);
  const [failed, setFailed] = useState(false);
  const known = useRef(new Map(initialSelected.map((game) => [game.id, game])));
  options.games.forEach((game) => known.current.set(game.id, game));
  const selected = selectedIds.flatMap((id) => {
    const game = known.current.get(id);
    return game ? [game] : [];
  });
  const selectedSet = new Set(selectedIds);
  const visible = [
    ...selected,
    ...options.games.filter((game) => !selectedSet.has(game.id)),
  ];
  const load = (page: number) => {
    setLoading(true);
    setFailed(false);
    router.reload({
      only: ["game_options"],
      data: { game_q: query, game_page: query === options.query ? page : 1 },
      preserveUrl: true,
      onError: () => setFailed(true),
      onFinish: () => setLoading(false),
    });
  };
  return (
    <>
      <div {...stylex.props(ui.actions)}>
        <input
          {...stylex.props(ui.input)}
          type="search"
          aria-label="Filter games"
          placeholder="Game code or team…"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          onKeyDown={(event) => {
            if (event.key === "Enter") {
              event.preventDefault();
              load(1);
            }
          }}
        />
        <button
          type="button"
          {...stylex.props(ui.nativeButton, ui.button)}
          disabled={loading}
          onClick={() => load(1)}
        >
          Search
        </button>
      </div>
      <p {...stylex.props(ui.paragraph, ui.hint)} role="status">
        {loading
          ? "Loading games…"
          : `${selectedIds.length} selected · ${options.pagination.total} matching games`}
      </p>
      {failed && <p role="alert">Couldn't load games. Please try again.</p>}
      <div {...stylex.props(ui.gamePicker)} aria-busy={loading}>
        {visible.map((game) => (
          <label {...stylex.props(ui.label, ui.gameOption)} key={game.id}>
            <input
              {...stylex.props(ui.checkbox)}
              type="checkbox"
              checked={selectedSet.has(game.id)}
              onChange={(event) =>
                onChange(
                  event.target.checked
                    ? [...selectedIds, game.id]
                    : selectedIds.filter((id) => id !== game.id),
                )
              }
            />
            <span>
              <strong {...stylex.props(ui.strong)}>
                {game.code || game.external_id} · {game.date}
              </strong>
              <small {...stylex.props(ui.small)}>{game.matchup}</small>
              <small {...stylex.props(ui.small)}>
                {money(game.fees_cents)} · {game.official_count} officials
              </small>
              {game.invoices
                .filter((other) => other.id !== invoiceId)
                .map((other) => (
                  <small {...stylex.props(ui.small, ui.amber)} key={other.id}>
                    Also linked to {other.number}
                  </small>
                ))}
            </span>
          </label>
        ))}
      </div>
      {!visible.length && (
        <p {...stylex.props(ui.paragraph, ui.hint)}>
          No matching games. Try a different search or import a Horizon file.
        </p>
      )}
      <div {...stylex.props(ui.tableBottom)}>
        <button
          type="button"
          {...stylex.props(ui.nativeButton, ui.button)}
          disabled={loading || options.pagination.page <= 1}
          onClick={() => load(options.pagination.page - 1)}
        >
          ← Previous
        </button>
        <span>
          {options.pagination.page} / {options.pagination.pages}
        </span>
        <button
          type="button"
          {...stylex.props(ui.nativeButton, ui.button)}
          disabled={
            loading || options.pagination.page >= options.pagination.pages
          }
          onClick={() => load(options.pagination.page + 1)}
        >
          Next →
        </button>
      </div>
    </>
  );
});
