import Link from "./AppLink";
import type { DraftMetadata } from "../types";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../styles/ui.stylex";
import { router } from "@inertiajs/react";
import { workbench } from "./DraftWorkbench.stylex";

export function DraftSwitcher({
  drafts,
  activeId,
}: {
  drafts: DraftMetadata[];
  activeId: number | null;
}) {
  return (
    <div {...stylex.props(workbench.bar)}>
      <div {...stylex.props(workbench.switcher)}>
        <label {...stylex.props(ui.label)} htmlFor="active-draft">
          Draft workbench
        </label>
        <select
          {...stylex.props(ui.input)}
          id="active-draft"
          value={activeId ?? ""}
          onChange={(event) => {
            if (event.target.value)
              router.visit(`/invoice_drafts/${event.target.value}/edit`);
          }}
        >
          {!drafts.some((draft) => draft.id === activeId) && (
            <option value={activeId ?? ""}>
              {activeId ? "Current draft" : "New draft"}
            </option>
          )}
          {drafts.map((draft) => (
            <option key={draft.id} value={draft.id}>
              {draft.title}
            </option>
          ))}
        </select>
      </div>
      <div {...stylex.props(ui.actions)}>
        <Link
          {...stylex.props(ui.link, ui.button)}
          href="/invoice_drafts"
          method="post"
          as="button"
        >
          + New draft
        </Link>
        <Link {...stylex.props(ui.link)} href="/invoice_drafts">
          All drafts →
        </Link>
      </div>
    </div>
  );
}

export function DraftShelf({ drafts }: { drafts: DraftMetadata[] }) {
  return (
    <section
      {...stylex.props(ui.card, workbench.shelf)}
      aria-label="Draft workbench"
    >
      <div {...stylex.props(workbench.heading)}>
        <div>
          <h2 {...stylex.props(ui.h2)}>Pick up where you left off.</h2>
          <p {...stylex.props(ui.paragraph)}>
            Autosaved drafts, ready whenever you are.
          </p>
        </div>
        <Link {...stylex.props(ui.link)} href="/invoice_drafts">
          All drafts →
        </Link>
      </div>
      <div {...stylex.props(workbench.grid)}>
        {drafts.map((draft) => (
          <Link
            {...stylex.props(ui.link, workbench.draft)}
            key={draft.id}
            href={`/invoice_drafts/${draft.id}/edit`}
          >
            <span {...stylex.props(workbench.caption)}>IN PROGRESS</span>
            <strong {...stylex.props(ui.strong)}>{draft.title}</strong>
            <small {...stylex.props(ui.small)}>
              Saved {new Date(draft.updated_at).toLocaleString("en-CA")}
            </small>
          </Link>
        ))}
        <Link
          {...stylex.props(ui.link, workbench.draft, workbench.newDraft)}
          href="/invoice_drafts"
          method="post"
          as="button"
        >
          + Start another draft
        </Link>
      </div>
    </section>
  );
}
