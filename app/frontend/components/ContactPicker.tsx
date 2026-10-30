import { memo, useState } from "react";
import { router } from "@inertiajs/react";
import type { ContactOptions, RecipientContact } from "../types";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../styles/ui.stylex";
import { browserStyles as styles } from "./GameBrowser.stylex";

export default memo(function ContactPicker({
  options,
  onChoose,
}: {
  options?: ContactOptions;
  onChoose: (contact: RecipientContact) => void;
}) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [loading, setLoading] = useState(false);
  const [failed, setFailed] = useState(false);
  const load = (page = 1) => {
    setLoading(true);
    setFailed(false);
    router.reload({
      only: ["contact_options"],
      data: { contact_q: query, contact_page: page },
      preserveUrl: true,
      onError: () => setFailed(true),
      onNetworkError: () => setFailed(true),
      onHttpException: () => setFailed(true),
      onFinish: () => setLoading(false),
    });
  };
  return (
    <div {...stylex.props(styles.contactPanel)}>
      <div {...stylex.props(ui.actions)}>
        <button
          type="button"
          {...stylex.props(ui.nativeButton, ui.button)}
          onClick={() => {
            setOpen(!open);
            if (!open) load();
          }}
        >
          {open ? "Close saved contacts" : "Choose a saved recipient"}
        </button>
        <a
          {...stylex.props(ui.link, ui.smallLink)}
          href="/contacts/new"
          target="_blank"
          rel="noopener"
        >
          + New contact ↗
        </a>
        <a
          {...stylex.props(ui.link, ui.smallLink)}
          href="/contacts"
          target="_blank"
          rel="noopener"
        >
          Manage contacts ↗
        </a>
      </div>
      {open && (
        <>
          <div {...stylex.props(ui.actions)}>
            <input
              {...stylex.props(ui.input)}
              type="search"
              aria-label="Search saved contacts"
              placeholder="Name, organization or email…"
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              onKeyDown={(event) => {
                if (event.key === "Enter") {
                  event.preventDefault();
                  load();
                }
              }}
            />
            <button
              type="button"
              {...stylex.props(ui.nativeButton, ui.button)}
              disabled={loading}
              onClick={() => load()}
            >
              Find contacts
            </button>
          </div>
          <p {...stylex.props(ui.paragraph, ui.hint)} role="status">
            {loading
              ? "Loading contacts…"
              : "Choosing a contact copies its recipient, contact and address fields into this draft. You can edit them afterward."}
          </p>
          {failed && (
            <p role="alert">Couldn't load contacts. Search again to retry.</p>
          )}
          {options?.contacts.map((contact) => (
            <div {...stylex.props(styles.contactRow)} key={contact.id}>
              <div>
                <strong {...stylex.props(ui.strong)}>
                  {contact.organization || contact.name}
                </strong>
                <small {...stylex.props(ui.small)}>
                  {contact.name}
                  {contact.email ? ` · ${contact.email}` : ""}
                </small>
                {contact.phone && (
                  <small {...stylex.props(ui.small)}>{contact.phone}</small>
                )}
              </div>
              <button
                type="button"
                {...stylex.props(ui.nativeButton, ui.button)}
                aria-label={`Use contact ${contact.name}`}
                onClick={() => {
                  onChoose(contact);
                  setOpen(false);
                }}
              >
                Use recipient
              </button>
            </div>
          ))}
          {options && !options.contacts.length && !loading && (
            <p {...stylex.props(ui.paragraph)}>
              No matching contacts. Create one, then search again.
            </p>
          )}
          {options && (
            <div {...stylex.props(ui.tableBottom)}>
              <button
                type="button"
                {...stylex.props(ui.nativeButton, ui.button)}
                disabled={loading || options.pagination.page <= 1}
                onClick={() =>
                  load(
                    query === options.query ? options.pagination.page - 1 : 1,
                  )
                }
              >
                ← Previous contacts
              </button>
              <span>
                {options.pagination.from}–{options.pagination.to} of{" "}
                {options.pagination.total}
              </span>
              <button
                type="button"
                {...stylex.props(ui.nativeButton, ui.button)}
                disabled={
                  loading || options.pagination.page >= options.pagination.pages
                }
                onClick={() =>
                  load(
                    query === options.query ? options.pagination.page + 1 : 1,
                  )
                }
              >
                Next contacts →
              </button>
            </div>
          )}
        </>
      )}
    </div>
  );
});
