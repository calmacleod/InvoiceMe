import * as stylex from "@stylexjs/stylex";
import { router } from "@inertiajs/react";
import type { InvoiceGroupEntry, InvoiceGroupReference } from "../types";
import { ui } from "../styles/ui.stylex";
import { workbench } from "./DraftWorkbench.stylex";
import Link from "./AppLink";

export default function InvoiceGroupSwitcher({
  group,
  activeDraftId,
  activeInvoiceId,
}: {
  group: InvoiceGroupReference & { entries: InvoiceGroupEntry[] };
  activeDraftId: number | null;
  activeInvoiceId: number | null;
}) {
  const url = `/invoice_groups/${group.id}`;
  const choices = group.entries.map(({ invoice, draft }) => ({
    url: draft
      ? `/invoice_drafts/${draft.id}/edit`
      : `/invoices/${invoice!.id}`,
    label: draft?.title ?? `${invoice!.number} · ${invoice!.recipient}`,
    active:
      (draft && draft.id === activeDraftId) ||
      (invoice && invoice.id === activeInvoiceId),
  }));
  const active = choices.find((choice) => choice.active);
  return (
    <div {...stylex.props(workbench.bar)}>
      <div {...stylex.props(workbench.switcher)}>
        <label {...stylex.props(ui.label)} htmlFor="group-invoice">
          Invoice in {group.name}
        </label>
        <select
          {...stylex.props(ui.input)}
          id="group-invoice"
          value={active?.url ?? ""}
          onChange={(event) => {
            if (event.target.value) router.visit(event.target.value);
          }}
        >
          {!active && <option value="">Current invoice</option>}
          {choices.map((choice) => (
            <option key={choice.url} value={choice.url}>
              {choice.label}
            </option>
          ))}
        </select>
      </div>
      <div {...stylex.props(ui.actions)}>
        <Link {...stylex.props(ui.link, ui.button)} href={url}>
          View group
        </Link>
        <Link
          {...stylex.props(ui.link, ui.button)}
          href="/invoice_drafts"
          method="post"
          as="button"
          data={{ invoice_group_id: group.id }}
        >
          + Add invoice
        </Link>
      </div>
    </div>
  );
}
