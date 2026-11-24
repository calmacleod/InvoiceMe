import { Dialog } from "@base-ui/react/dialog";
import { useState } from "react";
import { router } from "@inertiajs/react";
import type { GameDetail, GameSummary } from "../types";
import * as stylex from "@stylexjs/stylex";
import { date, money } from "../lib/format";
import { ui } from "../styles/ui.stylex";
import { browserStyles as styles } from "./GameBrowser.stylex";
import GameDetails from "./GameDetails";

export default function GameFeeDetails({ game }: { game: GameSummary }) {
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
    <Dialog.Root
      onOpenChange={(open) => {
        if (open && !detail && !loading) load();
      }}
    >
      <Dialog.Trigger
        {...stylex.props(ui.nativeButton, ui.textButton, ui.link, ui.smallLink)}
        aria-label={`View fees for game ${game.external_id}`}
      >
        {game.official_count}{" "}
        {game.official_count === 1 ? "official" : "officials"}
      </Dialog.Trigger>
      <Dialog.Portal>
        <Dialog.Backdrop {...stylex.props(styles.feeBackdrop)} />
        <Dialog.Popup {...stylex.props(styles.feeDialog)}>
          <div {...stylex.props(styles.feeDialogHeader)}>
            <div>
              <Dialog.Title {...stylex.props(ui.h2)}>
                Fees for game #{game.external_id}
              </Dialog.Title>
              <Dialog.Description {...stylex.props(ui.paragraph)}>
                {[game.matchup, date(game.date), money(game.fees_cents)]
                  .filter(Boolean)
                  .join(" · ")}
              </Dialog.Description>
            </div>
            <Dialog.Close {...stylex.props(ui.nativeButton, ui.button)}>
              Close
            </Dialog.Close>
          </div>
          {detail ? (
            <GameDetails game={detail} />
          ) : (
            <p role="status" {...stylex.props(ui.paragraph)}>
              {failed ? "Couldn’t load crew fees." : "Loading crew fees…"}
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
        </Dialog.Popup>
      </Dialog.Portal>
    </Dialog.Root>
  );
}
