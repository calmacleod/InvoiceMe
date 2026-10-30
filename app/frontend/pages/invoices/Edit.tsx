import Link from "../../components/AppLink";
import type { FormEvent } from "react";
import type {
  InvoiceDetail,
  InvoiceFields,
  InvoiceForm,
  EditableLineItem,
  GameOptions,
  GameSummary,
  DraftMetadata,
  ContactOptions,
  RecipientContact,
} from "../../types";
import type { FieldOptions } from "../../components/UI";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../../styles/ui.stylex";
import { Head, useForm, usePage } from "@inertiajs/react";
import { useCallback } from "react";
import { Errors, Field, Heading, Section } from "../../components/UI";
import GamePicker from "../../components/GamePicker";
import ContactPicker from "../../components/ContactPicker";
import { money } from "../../lib/format";
import { invoiceTotal } from "../../lib/money";
import useDraftAutosave from "../../lib/useDraftAutosave";
import { DraftSwitcher } from "../../components/DraftWorkbench";
import { workbench } from "../../components/DraftWorkbench.stylex";
type EditorProps = {
  invoice: InvoiceDetail;
  game_options: GameOptions;
  draft: DraftMetadata | null;
  draft_data: InvoiceForm | null;
  workbenches: DraftMetadata[];
  selected_games: GameSummary[];
  contact_options?: ContactOptions;
};
export default function Edit(props: EditorProps) {
  // POST redirects preserve Inertia state. Each workbench still needs its own
  // form and autosave writer when starting or switching to another draft.
  return (
    <InvoiceEditor
      key={
        props.draft
          ? `draft:${props.draft.id}`
          : `invoice:${props.invoice.id ?? "new"}`
      }
      {...props}
    />
  );
}
function InvoiceEditor({
  invoice,
  game_options,
  draft,
  draft_data,
  workbenches,
  selected_games,
  contact_options,
}: EditorProps) {
  const initial: InvoiceFields = {
    number: invoice.number ?? "",
    recipient: invoice.recipient ?? "",
    description: invoice.description ?? "",
    contact: invoice.contact ?? "",
    recipient_address: invoice.recipient_address ?? "",
    issued_on: invoice.issued_on ?? "",
    due_on: invoice.due_on ?? "",
    public_notes: invoice.public_notes ?? "",
    private_notes: invoice.private_notes ?? "",
  };
  const form = useForm<InvoiceForm>({
    ...initial,
    game_ids: invoice.game_ids,
    line_items_attributes: invoice.line_items.map((item, index) => ({
      id: item.id,
      description: item.description ?? "",
      quantity: item.quantity ?? "1",
      rate: item.rate ?? "",
      position: index,
      _destroy: false,
      key: item.id ?? `new-${index}`,
    })),
    ...draft_data,
  });
  const { current_season: season } = usePage().props;
  const autosave = useDraftAutosave(form.data, draft, season!.id, invoice.id);
  const activeDraft = autosave.state.metadata;
  const draftOptions = activeDraft
    ? [activeDraft, ...workbenches.filter((item) => item.id !== activeDraft.id)]
    : workbenches;
  const selectGames = useCallback(
    (ids: number[]) => form.setData("game_ids", ids),
    [form.setData],
  );
  const chooseContact = useCallback(
    (contact: RecipientContact) =>
      form.setData((previous) => ({
        ...previous,
        recipient: contact.recipient,
        contact: contact.contact,
        recipient_address: contact.address,
      })),
    [form.setData],
  );
  const changeLine = <Key extends keyof EditableLineItem>(
    index: number,
    key: Key,
    value: EditableLineItem[Key],
  ) =>
    form.setData(
      "line_items_attributes",
      form.data.line_items_attributes.map((item, i) =>
        i === index
          ? {
              ...item,
              [key]: value,
            }
          : item,
      ),
    );
  const field = (
    key: keyof InvoiceFields,
    label: string,
    props: FieldOptions = {},
  ) => (
    <Field
      name={key}
      label={label}
      value={form.data[key]}
      onChange={(value) => form.setData(key, value)}
      {...props}
    />
  );
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    try {
      const saved = await autosave.flush(true);
      form.transform(() => ({ lock_version: saved.lock_version }));
      form.post(`/invoice_drafts/${saved.id}/preview`);
    } catch {
      /* Autosave feedback keeps all unsaved fields visible. */
    }
  }
  return (
    <>
      <Head
        title={autosave.identity.invoice_id ? "Edit invoice" : "Create invoice"}
      />
      <Heading
        eyebrow="LET'S MAKE IT OFFICIAL"
        title={
          autosave.identity.invoice_id ? "Edit invoice" : "Create an invoice"
        }
      >
        Your work saves automatically. Preview everything before you publish.
      </Heading>
      <DraftSwitcher drafts={draftOptions} activeId={autosave.identity.id} />
      <div
        {...stylex.props(workbench.status)}
        aria-live="polite"
        role={autosave.state.phase === "error" ? "alert" : "status"}
      >
        <span>
          {autosave.state.phase === "saving"
            ? "Saving…"
            : autosave.state.phase === "waiting"
              ? "Unsaved changes…"
              : autosave.state.phase === "error"
                ? autosave.state.error
                : autosave.identity.id
                  ? "✓ All changes saved"
                  : "Start typing — your draft will save automatically."}
        </span>
        {autosave.state.phase === "error" && (
          <>
            <button
              type="button"
              {...stylex.props(ui.nativeButton, ui.button)}
              onClick={() => void autosave.flush().catch(() => {})}
            >
              Retry save
            </button>
            {autosave.state.conflict && (
              <button
                type="button"
                {...stylex.props(ui.nativeButton, ui.button)}
                onClick={() => {
                  void autosave
                    .saveCopy((data) => form.setData(data))
                    .catch(() => {});
                }}
              >
                Save as a separate draft
              </button>
            )}
            <a
              {...stylex.props(ui.link)}
              href={
                autosave.identity.id
                  ? `/invoice_drafts/${autosave.identity.id}/edit`
                  : "/session/new"
              }
              target="_blank"
              rel="noopener"
            >
              Open saved version in another tab ↗
            </a>
          </>
        )}
      </div>
      <form onSubmit={submit}>
        <fieldset
          disabled={form.processing}
          {...stylex.props(workbench.fields)}
        >
          <Errors errors={form.errors} />
          <div {...stylex.props(ui.editorLayout)}>
            <div>
              <Section
                step="01"
                title="Invoice details"
                hint="Who it's for and how you'll find it later."
              >
                <ContactPicker
                  options={contact_options}
                  onChoose={chooseContact}
                />
                <div {...stylex.props(ui.formGrid)}>
                  {field("number", "Invoice number", {
                    required: true,
                  })}
                  {field("recipient", "Bill to", {
                    required: true,
                  })}
                  {field("description", "Description for master ledger", {
                    required: true,
                  })}
                  {field("contact", "Contact name or email")}
                  {field("recipient_address", "Recipient address (optional)", {
                    multiline: true,
                    rows: 2,
                  })}
                  {field("issued_on", "Invoice date", {
                    type: "date",
                    required: true,
                  })}
                  {field("due_on", "Due date (optional)", {
                    type: "date",
                  })}
                </div>
              </Section>
              <Section
                step="02"
                title="Line items"
                hint="Set your own descriptions, quantities, and rates."
              >
                <div {...stylex.props(ui.lineItems)}>
                  {form.data.line_items_attributes.map(
                    (item, index) =>
                      !item._destroy && (
                        <div {...stylex.props(ui.lineRow)} key={item.key}>
                          <Field
                            name={`description-${index}`}
                            label="Description"
                            value={item.description}
                            onChange={(value) =>
                              changeLine(index, "description", value)
                            }
                            required
                          />
                          <Field
                            name={`quantity-${index}`}
                            label="Quantity"
                            type="number"
                            value={item.quantity}
                            onChange={(value) =>
                              changeLine(index, "quantity", value)
                            }
                            step="0.001"
                            min="0.001"
                            max="999999.999"
                            required
                          />
                          <Field
                            name={`rate-${index}`}
                            label="Rate (CAD)"
                            type="number"
                            value={item.rate}
                            onChange={(value) =>
                              changeLine(index, "rate", value)
                            }
                            step="0.01"
                            min="0"
                            max="999999.99"
                            required
                          />
                          <button
                            {...stylex.props(ui.nativeButton, ui.removeItem)}
                            type="button"
                            aria-label="Remove line item"
                            onClick={() => changeLine(index, "_destroy", true)}
                          >
                            ×
                          </button>
                        </div>
                      ),
                  )}
                </div>
                <button
                  {...stylex.props(ui.nativeButton, ui.button, ui.dashed)}
                  type="button"
                  onClick={() =>
                    form.setData("line_items_attributes", [
                      ...form.data.line_items_attributes,
                      {
                        key: crypto.randomUUID(),
                        description: "",
                        quantity: "1",
                        rate: "",
                        position: form.data.line_items_attributes.length,
                        _destroy: false,
                      },
                    ])
                  }
                >
                  + Add line item
                </button>
                <div {...stylex.props(ui.editorTotal)}>
                  <span>
                    Total <small {...stylex.props(ui.small)}>CAD</small>
                  </span>
                  <strong
                    {...stylex.props(ui.strong, ui.totalValue)}
                    aria-live="polite"
                  >
                    {money(invoiceTotal(form.data.line_items_attributes))}
                  </strong>
                </div>
              </Section>
              <Section
                step="03"
                title="Notes"
                hint="The right details, in the right place."
              >
                <div {...stylex.props(ui.formGrid)}>
                  {field("public_notes", "Notes on invoice", {
                    multiline: true,
                    rows: 4,
                  })}
                  {field("private_notes", "Private notes", {
                    multiline: true,
                    rows: 4,
                  })}
                </div>
              </Section>
            </div>
            <aside {...stylex.props(ui.editorAside)}>
              <Section
                title="Link Horizon games"
                hint="Links keep your records connected. Invoice amounts come from the line items you enter."
              >
                <GamePicker
                  options={game_options}
                  initialSelected={selected_games}
                  selectedIds={form.data.game_ids}
                  onChange={selectGames}
                  invoiceId={autosave.identity.invoice_id}
                  draftId={autosave.identity.id}
                />
              </Section>
              <div {...stylex.props(ui.tip)}>
                <strong {...stylex.props(ui.strong)}>
                  A draft is just a draft.
                </strong>
                <p {...stylex.props(ui.paragraph)}>
                  Leave and return whenever you like. Your drafts stay on the
                  workbench until you are ready to preview and publish.
                </p>
              </div>
            </aside>
          </div>
          <div {...stylex.props(ui.formActions, ui.sticky)}>
            <Link {...stylex.props(ui.link, ui.button)} href="/">
              Back to invoices
            </Link>
            <button
              {...stylex.props(ui.nativeButton, ui.button, ui.primary)}
              disabled={form.processing || autosave.state.phase === "saving"}
            >
              Save & preview →
            </button>
          </div>
        </fieldset>
      </form>
    </>
  );
}
