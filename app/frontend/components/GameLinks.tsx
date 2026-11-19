import type { GameSummary } from "../types";
import Link from "./AppLink";
import * as stylex from "@stylexjs/stylex";
import { browserStyles as styles } from "./GameBrowser.stylex";

export default function GameLinks({
  game,
  invoiceId,
  draftId,
  selected = false,
  groupSelection = false,
}: {
  game: GameSummary;
  invoiceId?: number | null;
  draftId?: number | null;
  selected?: boolean;
  groupSelection?: boolean;
}) {
  const workbenches = game.workbenches.filter((draft) => draft.id !== draftId);
  const groups = game.invoice_groups ?? [];
  return (
    <div>
      {game.already_invoiced && (
        <span {...stylex.props(styles.linkStatus)}>Already invoiced</span>
      )}
      {selected && (
        <span {...stylex.props(styles.linkStatus)}>
          {groupSelection
            ? "Selected for this group"
            : "Selected on this draft"}
        </span>
      )}
      {!selected &&
        !game.already_invoiced &&
        !game.invoices.length &&
        !groups.length &&
        !workbenches.length && (
          <span {...stylex.props(styles.linkStatus, styles.unlinked)}>
            Not linked
          </span>
        )}
      {groups.map((group) => (
        <div key={group.id}>
          <Link
            {...stylex.props(styles.linkStatus)}
            href={`/invoice_groups/${group.id}`}
          >
            {group.name}
          </Link>
        </div>
      ))}
      {game.invoices.map((invoice) => (
        <div key={invoice.id}>
          <Link
            {...stylex.props(styles.linkStatus)}
            href={`/invoices/${invoice.id}`}
          >
            {invoice.finalized_at ? "Invoice" : "Draft invoice"}:{" "}
            {invoice.number}
            {invoice.id === invoiceId ? " (this invoice)" : ""}
          </Link>
        </div>
      ))}
      {workbenches.map((draft) => (
        <div key={draft.id}>
          <Link
            {...stylex.props(styles.linkStatus)}
            href={`/invoice_drafts/${draft.id}/edit`}
          >
            Workbench: {draft.title}
          </Link>
        </div>
      ))}
    </div>
  );
}
