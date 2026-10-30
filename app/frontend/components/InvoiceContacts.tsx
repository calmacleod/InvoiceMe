import type { InvoiceContact } from "../types";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../styles/ui.stylex";
import { browserStyles as styles } from "./GameBrowser.stylex";
import { Field } from "./UI";

export default function InvoiceContacts({
  contacts,
  onChange,
}: {
  contacts: InvoiceContact[];
  onChange: (contacts: InvoiceContact[]) => void;
}) {
  function move(index: number, offset: number) {
    const next = [...contacts];
    [next[index], next[index + offset]] = [next[index + offset], next[index]];
    onChange(next);
  }

  return (
    <div {...stylex.props(styles.contactPanel)}>
      <strong {...stylex.props(ui.strong)}>Invoice contacts</strong>
      <p {...stylex.props(ui.paragraph, ui.hint)}>
        Only names appear on the invoice. The master spreadsheet uses the first
        email listed. Move contacts to change that order.
      </p>
      {contacts.map((contact, index) => (
        <div
          {...stylex.props(styles.contactPanel)}
          key={index}
          role="group"
          aria-label={`Invoice contact ${index + 1}`}
        >
          <div {...stylex.props(ui.formGrid)}>
            <Field
              name={`contact-name-${index}`}
              label={`Contact ${index + 1} name`}
              value={contact.name}
              maxLength={200}
              onChange={(name) =>
                onChange(
                  contacts.map((item, i) =>
                    i === index ? { ...item, name } : item,
                  ),
                )
              }
            />
            <Field
              name={`contact-email-${index}`}
              label={`Contact ${index + 1} email (optional)`}
              value={contact.email}
              type="email"
              maxLength={250}
              onChange={(email) =>
                onChange(
                  contacts.map((item, i) =>
                    i === index ? { ...item, email } : item,
                  ),
                )
              }
            />
          </div>
          <div {...stylex.props(ui.actions)}>
            <button
              type="button"
              {...stylex.props(ui.nativeButton, ui.button)}
              aria-label={`Move contact ${index + 1} up`}
              disabled={index === 0}
              onClick={() => move(index, -1)}
            >
              ↑
            </button>
            <button
              type="button"
              {...stylex.props(ui.nativeButton, ui.button)}
              aria-label={`Move contact ${index + 1} down`}
              disabled={index === contacts.length - 1}
              onClick={() => move(index, 1)}
            >
              ↓
            </button>
            <button
              type="button"
              {...stylex.props(ui.nativeButton, ui.button)}
              aria-label={`Remove contact ${index + 1}`}
              onClick={() => onChange(contacts.filter((_, i) => i !== index))}
            >
              Remove
            </button>
          </div>
        </div>
      ))}
      <button
        type="button"
        {...stylex.props(ui.nativeButton, ui.button)}
        onClick={() => onChange([...contacts, { name: "", email: "" }])}
      >
        + Add contact manually
      </button>
    </div>
  );
}
