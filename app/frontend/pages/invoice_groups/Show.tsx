import { Head, router, useForm } from "@inertiajs/react";
import { useEffect } from "react";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../../styles/ui.stylex";
import type {
  GameOptions,
  GameSummary,
  InvoiceGroupEntry,
  InvoiceGroupReference,
} from "../../types";
import Link from "../../components/AppLink";
import GamePicker from "../../components/GamePicker";
import { Badge, Errors, Field, Heading, Section } from "../../components/UI";
import { money } from "../../lib/format";
import { workbench } from "../../components/DraftWorkbench.stylex";

type Props = {
  group: InvoiceGroupReference & {
    lock_version: number;
    game_ids: number[];
    games_locked: boolean;
  };
  entries: InvoiceGroupEntry[];
  selected_games: GameSummary[];
  game_options: GameOptions;
};

export default function Show(props: Props) {
  return (
    <GroupWorkbench
      key={`${props.group.id}:${props.group.lock_version}:${props.group.games_locked}`}
      {...props}
    />
  );
}

function GroupWorkbench({
  group,
  entries,
  selected_games,
  game_options,
}: Props) {
  const url = `/invoice_groups/${group.id}`;
  const form = useForm({
    name: group.name,
    game_ids: group.game_ids,
    lock_version: group.lock_version,
  });
  useEffect(() => {
    if (!form.isDirty) return;

    const remove = router.on("before", (event) => {
      const { visit } = event.detail;
      if (visit.prefetch || visit.only.length || visit.method === "patch")
        return;
      if (
        !window.confirm("Leave without saving changes to this invoice group?")
      )
        event.preventDefault();
    });
    const warn = (event: BeforeUnloadEvent) => event.preventDefault();
    window.addEventListener("beforeunload", warn);
    return () => {
      remove();
      window.removeEventListener("beforeunload", warn);
    };
  }, [form.isDirty]);

  return (
    <>
      <Head title={group.name} />
      <Heading
        title={group.name}
        actions={
          <Link {...stylex.props(ui.link, ui.button)} href="/invoice_groups">
            All invoice groups
          </Link>
        }
      >
        {group.game_ids.length} shared{" "}
        {group.game_ids.length === 1 ? "game" : "games"}
      </Heading>

      <div {...stylex.props(ui.editorMain)}>
        <section
          {...stylex.props(ui.card, ui.tableCard)}
          aria-label="Invoices in this group"
        >
          <div {...stylex.props(ui.tableHeading)}>
            <h2 {...stylex.props(ui.h2)}>Invoices in this group</h2>
            <div {...stylex.props(ui.actions)}>
              <Link
                {...stylex.props(ui.link, ui.button)}
                href={`${url}/add_existing`}
              >
                Add existing invoice
              </Link>
              <Link
                {...stylex.props(ui.link, ui.button, ui.primary)}
                href="/invoice_drafts"
                method="post"
                as="button"
                data={{ invoice_group_id: group.id }}
              >
                New invoice
              </Link>
            </div>
          </div>
          {entries.length ? (
            <div {...stylex.props(ui.tableScroll)}>
              <table {...stylex.props(ui.table)}>
                <thead>
                  <tr>
                    <th {...stylex.props(ui.th)}>Invoice</th>
                    <th {...stylex.props(ui.th)}>Status</th>
                    <th {...stylex.props(ui.th, ui.numeric)}>Total (CAD)</th>
                    <th {...stylex.props(ui.th)}>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {entries.map(({ invoice, draft }) => (
                    <tr
                      key={
                        invoice ? `invoice-${invoice.id}` : `draft-${draft!.id}`
                      }
                    >
                      <td {...stylex.props(ui.td)}>
                        {invoice ? (
                          <>
                            <Link
                              {...stylex.props(ui.link, ui.strong)}
                              href={`/invoices/${invoice.id}`}
                            >
                              {invoice.recipient}
                            </Link>
                            <small {...stylex.props(ui.small)}>
                              {invoice.number} · {invoice.description}
                            </small>
                          </>
                        ) : (
                          <strong {...stylex.props(ui.strong)}>
                            {draft!.title}
                          </strong>
                        )}
                      </td>
                      <td {...stylex.props(ui.td)}>
                        <Badge status={invoice?.status ?? "Draft"} />
                      </td>
                      <td {...stylex.props(ui.td, ui.numeric)}>
                        {invoice ? money(invoice.total_cents) : "—"}
                      </td>
                      <td {...stylex.props(ui.td)}>
                        {draft ? (
                          <Link
                            {...stylex.props(ui.link, ui.button)}
                            href={`/invoice_drafts/${draft.id}/edit`}
                          >
                            Resume draft
                          </Link>
                        ) : (
                          <Link
                            {...stylex.props(ui.link, ui.button)}
                            href={`/invoices/${invoice!.id}`}
                          >
                            View invoice
                          </Link>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <p {...stylex.props(ui.empty)}>Add an invoice for each payer.</p>
          )}
        </section>

        <form
          onSubmit={(event) => {
            event.preventDefault();
            form.patch(url, { preserveScroll: true });
          }}
        >
          <Section
            title="Shared Horizon games"
            hint={
              group.games_locked
                ? "The game selection is locked because an invoice has been finalized or is exporting."
                : "Changes to the game selection apply to every invoice in this group."
            }
          >
            <fieldset
              disabled={form.processing}
              {...stylex.props(workbench.fields, ui.groupFields)}
            >
              <Errors errors={form.errors} />
              <div {...stylex.props(ui.formGrid)}>
                <Field
                  name="group-name"
                  label="Group name"
                  value={form.data.name}
                  onChange={(value) => form.setData("name", value)}
                  required
                  maxLength={120}
                />
              </div>
              <GamePicker
                options={game_options}
                initialSelected={selected_games}
                selectedIds={form.data.game_ids}
                onChange={(ids) => form.setData("game_ids", ids)}
                readOnly={group.games_locked}
              />
              <div {...stylex.props(ui.actions)}>
                <button
                  {...stylex.props(ui.nativeButton, ui.button, ui.primary)}
                  disabled={!form.isDirty || form.processing}
                >
                  Save group changes
                </button>
              </div>
            </fieldset>
          </Section>
        </form>
      </div>
    </>
  );
}
