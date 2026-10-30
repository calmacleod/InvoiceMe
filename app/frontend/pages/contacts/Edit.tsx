import { Head, useForm } from "@inertiajs/react";
import Link from "../../components/AppLink";
import { Heading, Field, Errors, Section } from "../../components/UI";
import type { ContactFields, ContactRecord } from "../../types";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../../styles/ui.stylex";

const fields: [keyof ContactFields, string][] = [
  ["name", "Contact name"],
  ["organization", "Organization / bill to"],
  ["email", "Email"],
  ["phone", "Phone"],
  ["address", "Mailing address"],
  ["notes", "Private contact notes"],
];
export default function Edit({ contact }: { contact: ContactRecord }) {
  const form = useForm<ContactFields>({
    name: contact.name ?? "",
    organization: contact.organization ?? "",
    email: contact.email ?? "",
    phone: contact.phone ?? "",
    address: contact.address ?? "",
    notes: contact.notes ?? "",
  });
  return (
    <>
      <Head title={contact.id ? "Edit contact" : "New contact"} />
      <Heading title={contact.id ? "Edit contact" : "New contact"}>
        Choosing this contact fills the invoice recipient, contact and address.
        Notes stay in your contact list.
      </Heading>
      <form
        onSubmit={(event) => {
          event.preventDefault();
          form.transform((data) => ({ contact: data }));
          if (contact.id) form.patch(`/contacts/${contact.id}`);
          else form.post("/contacts");
        }}
      >
        <Errors errors={form.errors} />
        <Section
          title="Contact details"
          hint="Contacts are available in every invoice year."
        >
          <div {...stylex.props(ui.formGrid)}>
            {fields.map(([key, label]) => (
              <Field
                key={key}
                name={`contact-${key}`}
                label={label}
                value={form.data[key]}
                onChange={(value) => form.setData(key, value)}
                required={key === "name"}
                type={
                  key === "email" ? "email" : key === "phone" ? "tel" : "text"
                }
                multiline={key === "address" || key === "notes"}
                rows={4}
                disabled={form.processing}
              />
            ))}
          </div>
        </Section>
        <div {...stylex.props(ui.formActions)}>
          <Link {...stylex.props(ui.link, ui.button)} href="/contacts">
            Cancel
          </Link>
          <button
            {...stylex.props(ui.nativeButton, ui.button, ui.primary)}
            disabled={form.processing}
          >
            Save contact
          </button>
        </div>
      </form>
    </>
  );
}
