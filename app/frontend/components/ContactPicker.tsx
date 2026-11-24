import { useEffect, useId, useRef, useState, type FormEvent } from "react";
import { createPortal } from "react-dom";
import { router } from "@inertiajs/react";
import type {
  ContactFields,
  ContactOptions,
  InvoiceContact,
  RecipientContact,
} from "../types";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../styles/ui.stylex";
import { contacts } from "./ContactPicker.stylex";
import { Errors, Field, PageSizeSelect } from "./UI";

const newContact: ContactFields = {
  name: "",
  organization: "",
  email: "",
  phone: "",
  address: "",
  notes: "",
};

export default function ContactPicker({
  selected,
  onChoose,
}: {
  selected: InvoiceContact[];
  onChoose: (contact: RecipientContact) => void;
}) {
  const [open, setOpen] = useState(false);
  return (
    <>
      <button
        type="button"
        {...stylex.props(ui.nativeButton, ui.button)}
        onClick={() => setOpen(true)}
      >
        Add contacts
      </button>
      {open &&
        createPortal(
          <ContactDialog
            selected={selected}
            onChoose={onChoose}
            onClose={() => setOpen(false)}
          />,
          document.body,
        )}
    </>
  );
}

function ContactDialog({
  selected,
  onChoose,
  onClose,
}: {
  selected: InvoiceContact[];
  onChoose: (contact: RecipientContact) => void;
  onClose: () => void;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  const titleId = useId();
  const searchInput = useRef<HTMLInputElement>(null);
  const [query, setQuery] = useState("");
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);
  const [retry, setRetry] = useState(0);
  const [result, setResult] = useState<{
    key: string;
    options?: ContactOptions;
    sessionExpired?: boolean;
  }>();
  const [creating, setCreating] = useState(false);
  const [fields, setFields] = useState(newContact);
  const [processing, setProcessing] = useState(false);
  const [errors, setErrors] = useState<Record<string, string | string[]>>({});
  const requestKey = JSON.stringify([query, page, pageSize, retry]);
  const options = result?.key === requestKey ? result.options : undefined;
  const failed = result?.key === requestKey && !result.options;

  useEffect(() => {
    if (!dialog.current?.open) dialog.current?.showModal();
    if (!creating) searchInput.current?.focus();
  }, [creating]);

  useEffect(() => {
    if (creating) return;
    const controller = new AbortController();
    const search = new URLSearchParams({
      q: query,
      page: String(page),
      per_page: String(pageSize),
    });
    const timer = window.setTimeout(
      async () => {
        try {
          const response = await fetch(`/contacts.json?${search}`, {
            signal: controller.signal,
            redirect: "error",
          });
          if (response.status === 401) {
            if (!controller.signal.aborted)
              setResult({ key: requestKey, sessionExpired: true });
            return;
          }
          if (!response.ok) throw new Error("Contact search failed");
          const options: ContactOptions = await response.json();
          if (!controller.signal.aborted)
            setResult({ key: requestKey, options });
        } catch {
          if (!controller.signal.aborted) setResult({ key: requestKey });
        }
      },
      query ? 180 : 0,
    );
    return () => {
      window.clearTimeout(timer);
      controller.abort();
    };
  }, [creating, page, pageSize, query, requestKey]);

  async function saveContact(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    event.stopPropagation();
    if (processing) return;
    setProcessing(true);
    setErrors({});
    try {
      const response = await fetch("/contacts.json", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token":
            document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')
              ?.content ?? "",
        },
        body: JSON.stringify({ contact: fields }),
        redirect: "error",
      });
      if (response.status === 422) {
        const error: { errors: Record<string, string[]> } =
          await response.json();
        setErrors(error.errors);
        return;
      }
      if (response.status === 401) {
        setErrors({
          base: "Your session expired. Sign in again to save contacts.",
        });
        return;
      }
      if (!response.ok) throw new Error("Contact save failed");
      const contact: RecipientContact = await response.json();
      router.flushAll();
      onChoose(contact);
      dialog.current?.close();
    } catch {
      setErrors({ base: "Couldn’t save this contact. Try again." });
    } finally {
      setProcessing(false);
    }
  }

  function changeField(key: keyof ContactFields, value: string) {
    setFields((previous) => ({ ...previous, [key]: value }));
  }

  return (
    <dialog
      ref={dialog}
      {...stylex.props(ui.app, contacts.dialog)}
      aria-labelledby={titleId}
      onClose={onClose}
      onCancel={(event) => {
        if (processing) event.preventDefault();
      }}
    >
      <div {...stylex.props(contacts.dialogBar)}>
        <h2 id={titleId} {...stylex.props(ui.h2, contacts.dialogTitle)}>
          {creating ? "New contact" : "Add contacts"}
        </h2>
        <button
          type="button"
          {...stylex.props(ui.nativeButton, ui.button)}
          disabled={processing}
          onClick={() => dialog.current?.close()}
        >
          Done
        </button>
      </div>
      {creating ? (
        <form {...stylex.props(contacts.dialogBody)} onSubmit={saveContact}>
          <Errors errors={errors} />
          <fieldset {...stylex.props(ui.fieldset)} disabled={processing}>
            <div {...stylex.props(ui.formGrid)}>
              <Field
                name="picker-name"
                label="Contact name"
                autoFocus
                required
                maxLength={200}
                value={fields.name}
                onChange={(value) => changeField("name", value)}
              />
              <Field
                name="picker-organization"
                label="Organization"
                maxLength={250}
                value={fields.organization}
                onChange={(value) => changeField("organization", value)}
              />
              <Field
                name="picker-email"
                label="Email"
                type="email"
                maxLength={250}
                value={fields.email}
                onChange={(value) => changeField("email", value)}
              />
              <Field
                name="picker-phone"
                label="Phone"
                type="tel"
                maxLength={80}
                value={fields.phone}
                onChange={(value) => changeField("phone", value)}
              />
              <div {...stylex.props(contacts.wide)}>
                <Field
                  name="picker-address"
                  label="Mailing address"
                  multiline
                  rows={2}
                  maxLength={4000}
                  value={fields.address}
                  onChange={(value) => changeField("address", value)}
                />
              </div>
            </div>
            <div {...stylex.props(ui.formActions)}>
              <button
                type="button"
                {...stylex.props(ui.nativeButton, ui.button)}
                onClick={() => setCreating(false)}
              >
                Back to search
              </button>
              <button {...stylex.props(ui.nativeButton, ui.button, ui.primary)}>
                {processing ? "Saving…" : "Save & add to invoice"}
              </button>
            </div>
          </fieldset>
        </form>
      ) : (
        <div {...stylex.props(contacts.dialogBody)}>
          <div {...stylex.props(contacts.searchRow)}>
            <input
              {...stylex.props(ui.input)}
              type="search"
              ref={searchInput}
              aria-label="Search saved contacts"
              placeholder="Name, organization or email"
              value={query}
              onChange={(event) => {
                setQuery(event.target.value);
                setPage(1);
              }}
            />
            <button
              type="button"
              {...stylex.props(ui.nativeButton, ui.button, ui.primary)}
              onClick={() => {
                setFields((previous) => ({
                  ...previous,
                  name: previous.name || query.trim(),
                }));
                setCreating(true);
              }}
            >
              New contact
            </button>
          </div>
          {failed ? (
            <p
              role="alert"
              {...stylex.props(ui.paragraph, contacts.resultsBar)}
            >
              {result.sessionExpired
                ? "Your session expired. Sign in again to use saved contacts."
                : "Couldn’t load contacts."}{" "}
              <button
                type="button"
                {...stylex.props(ui.nativeButton, ui.textButton, ui.smallLink)}
                onClick={() => setRetry(retry + 1)}
              >
                Retry
              </button>
            </p>
          ) : (
            !options?.contacts.length && (
              <p
                role="status"
                {...stylex.props(ui.paragraph, ui.hint, contacts.resultsBar)}
              >
                {!options
                  ? "Searching…"
                  : !options.contacts.length
                    ? "No contacts found."
                    : ""}
              </p>
            )
          )}
          {!!options?.contacts.length && (
            <ul {...stylex.props(contacts.matchList)}>
              {options.contacts.map((contact) => {
                const added = selected.some(
                  (item) =>
                    item.name === contact.name &&
                    item.email === (contact.email ?? ""),
                );
                return (
                  <li key={contact.id} {...stylex.props(contacts.match)}>
                    <span>
                      <strong>{contact.name}</strong>
                      {(contact.organization || contact.email) && (
                        <small {...stylex.props(ui.small)}>
                          {[contact.organization, contact.email]
                            .filter(Boolean)
                            .join(" · ")}
                        </small>
                      )}
                    </span>
                    <button
                      type="button"
                      {...stylex.props(
                        ui.nativeButton,
                        ui.button,
                        contacts.compactButton,
                      )}
                      aria-label={`Use contact ${contact.name}`}
                      disabled={added}
                      onClick={() => onChoose(contact)}
                    >
                      {added ? "Added" : "Add contact"}
                    </button>
                  </li>
                );
              })}
            </ul>
          )}
          {!!options?.contacts.length && (
            <nav
              {...stylex.props(ui.tableBottom, contacts.pagination)}
              aria-label="Saved contact pagination"
            >
              <span role="status">
                {options.pagination.from}–{options.pagination.to} of{" "}
                {options.pagination.total}
              </span>
              {options.pagination.total > 10 && (
                <div {...stylex.props(ui.actions)}>
                  <PageSizeSelect
                    pagination={options.pagination}
                    onChange={(size) => {
                      setPageSize(size);
                      setPage(1);
                    }}
                  />
                  <button
                    type="button"
                    {...stylex.props(
                      ui.nativeButton,
                      ui.button,
                      contacts.compactButton,
                    )}
                    aria-label="Previous contacts"
                    disabled={page <= 1}
                    onClick={() => setPage(page - 1)}
                  >
                    Previous
                  </button>
                  <button
                    type="button"
                    {...stylex.props(
                      ui.nativeButton,
                      ui.button,
                      contacts.compactButton,
                    )}
                    aria-label="Next contacts"
                    disabled={page >= options.pagination.pages}
                    onClick={() => setPage(page + 1)}
                  >
                    Next
                  </button>
                </div>
              )}
            </nav>
          )}
        </div>
      )}
    </dialog>
  );
}
