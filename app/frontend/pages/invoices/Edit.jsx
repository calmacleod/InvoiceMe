import { Head, Link, useForm } from "@inertiajs/react";
import { useState } from "react";
import { Errors, Field, Heading, Section, money } from "../../components/UI";
import { invoiceTotal } from "../../lib/money";

export default function Edit({ invoice, games }) {
  const initial = Object.fromEntries(
    [
      "number",
      "recipient",
      "description",
      "contact",
      "recipient_address",
      "issued_on",
      "due_on",
      "public_notes",
      "private_notes",
    ].map((key) => [key, invoice[key] ?? ""]),
  );
  const form = useForm({
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
  });
  const [filter, setFilter] = useState("");
  const changeLine = (index, key, value) =>
    form.setData(
      "line_items_attributes",
      form.data.line_items_attributes.map((item, i) =>
        i === index ? { ...item, [key]: value } : item,
      ),
    );
  const field = (key, label, props = {}) => (
    <Field
      name={key}
      label={label}
      value={form.data[key]}
      onChange={(value) => form.setData(key, value)}
      {...props}
    />
  );
  function submit(event) {
    event.preventDefault();
    form.transform((data) => ({
      invoice: {
        ...data,
        line_items_attributes: data.line_items_attributes.map(
          ({ key, ...item }) => item,
        ),
      },
    }));
    if (invoice.id) form.patch(`/invoices/${invoice.id}`);
    else form.post("/invoices");
  }
  return (
    <>
      <Head title={invoice.id ? "Edit invoice" : "Create invoice"} />
      <Heading
        eyebrow="LET'S MAKE IT OFFICIAL"
        title={invoice.id ? "Edit invoice" : "Create an invoice"}
      >
        Start with the details. Preview everything before you publish.
      </Heading>
      <form onSubmit={submit}>
        <Errors errors={form.errors} />
        <div className="editor-layout">
          <div>
            <Section
              step="01"
              title="Invoice details"
              hint="Who it's for and how you'll find it later."
            >
              <div className="form-grid">
                {field("number", "Invoice number", { required: true })}
                {field("recipient", "Bill to", { required: true })}
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
                {field("due_on", "Due date (optional)", { type: "date" })}
              </div>
            </Section>
            <Section
              step="02"
              title="Line items"
              hint="Set your own descriptions, quantities, and rates."
            >
              <div className="line-items">
                {form.data.line_items_attributes.map(
                  (item, index) =>
                    !item._destroy && (
                      <div className="line-row" key={item.key}>
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
                          onChange={(value) => changeLine(index, "rate", value)}
                          step="0.01"
                          min="0"
                          max="999999.99"
                          required
                        />
                        <button
                          type="button"
                          aria-label="Remove line item"
                          className="remove-item"
                          onClick={() => changeLine(index, "_destroy", true)}
                        >
                          ×
                        </button>
                      </div>
                    ),
                )}
              </div>
              <button
                type="button"
                className="button dashed"
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
              <div className="editor-total">
                <span>
                  Total <small>CAD</small>
                </span>
                <strong aria-live="polite">
                  {money(invoiceTotal(form.data.line_items_attributes))}
                </strong>
              </div>
            </Section>
            <Section
              step="03"
              title="Notes"
              hint="The right details, in the right place."
            >
              <div className="form-grid">
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
          <aside className="editor-aside">
            <Section
              title="Link Horizon games"
              hint="Links keep your records connected. Invoice amounts come from the line items you enter."
            >
              <input
                type="search"
                aria-label="Filter games"
                placeholder="Filter by game code or team…"
                value={filter}
                onChange={(event) => setFilter(event.target.value)}
              />
              <div className="game-picker">
                {games
                  .filter((game) =>
                    `${game.code} ${game.external_id} ${game.matchup}`
                      .toLowerCase()
                      .includes(filter.toLowerCase()),
                  )
                  .map((game) => (
                    <label className="game-option" key={game.id}>
                      <input
                        type="checkbox"
                        checked={form.data.game_ids.includes(game.id)}
                        onChange={(event) =>
                          form.setData(
                            "game_ids",
                            event.target.checked
                              ? [...form.data.game_ids, game.id]
                              : form.data.game_ids.filter(
                                  (id) => id !== game.id,
                                ),
                          )
                        }
                      />
                      <span>
                        <strong>
                          {game.code || game.external_id} · {game.date}
                        </strong>
                        <small>{game.matchup}</small>
                        <small>
                          {money(game.fees_cents)} · {game.official_count}{" "}
                          officials
                        </small>
                        {game.invoices
                          .filter((other) => other.id !== invoice.id)
                          .map((other) => (
                            <small key={other.id} className="amber">
                              Also linked to {other.number}
                            </small>
                          ))}
                      </span>
                    </label>
                  ))}
              </div>
              {!games.length && (
                <>
                  <p className="hint">No games imported for this year yet.</p>
                  <Link href="/games/new" className="small-link">
                    Import games →
                  </Link>
                </>
              )}
            </Section>
            <div className="tip">
              <strong>A draft is just a draft.</strong>
              <p>
                Save and preview your invoice first. Publish when you're happy
                with it.
              </p>
            </div>
          </aside>
        </div>
        <div className="form-actions sticky">
          <Link
            href={invoice.id ? `/invoices/${invoice.id}` : "/"}
            className="button"
          >
            Cancel
          </Link>
          <button className="button primary" disabled={form.processing}>
            Save & preview →
          </button>
        </div>
      </form>
    </>
  );
}
