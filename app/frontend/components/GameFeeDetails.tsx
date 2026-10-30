import { useState } from "react";
import { router } from "@inertiajs/react";
import type { GameDetail, GameSummary } from "../types";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../styles/ui.stylex";
import { browserStyles as styles } from "./GameBrowser.stylex";
import GameDetails from "./GameDetails";

export default function GameFeeDetails({ game }: { game: GameSummary }) {
  const [open, setOpen] = useState(false);
  const [detail, setDetail] = useState<GameDetail | null>(null);
  const [loading, setLoading] = useState(false);
  const [failed, setFailed] = useState(false);
  const load = () => {
    setLoading(true);
    setFailed(false);
    router.reload({
      only: ["game_detail"],
      data: { detail_id: game.id },
      preserveUrl: true,
      onSuccess: (page) => {
        const value = page.props.game_detail as GameDetail | undefined;
        if (value?.id === game.id) setDetail(value);
        else setFailed(true);
      },
      onError: () => setFailed(true),
      onNetworkError: () => setFailed(true),
      onHttpException: () => setFailed(true),
      onFinish: () => setLoading(false),
    });
  };
  return (
    <>
      <button
        type="button"
        {...stylex.props(ui.nativeButton, ui.textButton, ui.link, ui.smallLink)}
        aria-expanded={open}
        onClick={() => {
          setOpen(!open);
          if (!open && !detail && !loading) load();
        }}
      >
        {game.official_count} officials · {open ? "Hide fees" : "View fees"}
      </button>
      {open && (
        <div {...stylex.props(styles.detail)}>
          {detail ? (
            <GameDetails game={detail} />
          ) : (
            <p role="status">
              {loading ? "Loading crew fees…" : "Couldn't load crew fees."}
            </p>
          )}
          {failed && (
            <button
              type="button"
              {...stylex.props(ui.nativeButton, ui.button)}
              onClick={load}
            >
              Retry fees
            </button>
          )}
        </div>
      )}
    </>
  );
}
