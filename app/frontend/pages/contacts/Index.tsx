import { Head, useForm } from "@inertiajs/react";
import Link from "../../components/AppLink";
import { Heading, PaginationControls, Search } from "../../components/UI";
import type { RecipientContact, Pagination } from "../../types";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../../styles/ui.stylex";

export default function Index({
  contacts,
  pagination,
  query,
}: {
  contacts: RecipientContact[];
  pagination: Pagination;
  query: string;
}) {
  const deletion = useForm({});
  return (
    <>
      <Head title="Contacts" />
      <Heading
        eyebrow="LESS REPEATED TYPING"
        title="Contacts."
        actions={
          <Link
            {...stylex.props(ui.link, ui.button, ui.primary)}
            href="/contacts/new"
          >
            + New contact
          </Link>
        }
      >
        Save common recipients once and reuse them across invoice years.
      </Heading>
      <section {...stylex.props(ui.card, ui.tableCard)}>
        <div {...stylex.props(ui.tableHeading)}>
          <h2 {...stylex.props(ui.h2)}>
            {pagination.total} saved{" "}
            {pagination.total === 1 ? "contact" : "contacts"}
          </h2>
          <Search
            url="/contacts"
            query={query}
            label="Search contacts"
            only={["contacts", "pagination", "query"]}
          />
        </div>
        <div {...stylex.props(ui.tableScroll)}>
          <table {...stylex.props(ui.table)}>
            <thead>
              <tr>
                <th {...stylex.props(ui.th)}>Name / organization</th>
                <th {...stylex.props(ui.th)}>Email / phone</th>
                <th {...stylex.props(ui.th)}>Mailing address</th>
                <th {...stylex.props(ui.th)}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {contacts.map((contact) => (
                <tr key={contact.id}>
                  <td {...stylex.props(ui.td)}>
                    <Link
                      {...stylex.props(ui.link)}
                      href={`/contacts/${contact.id}/edit`}
                    >
                      <strong {...stylex.props(ui.strong)}>
                        {contact.name}
                      </strong>
                    </Link>
                    <small {...stylex.props(ui.small)}>
                      {contact.organization}
                    </small>
                  </td>
                  <td {...stylex.props(ui.td)}>
                    {contact.email}
                    <small {...stylex.props(ui.small)}>{contact.phone}</small>
                  </td>
                  <td {...stylex.props(ui.td, ui.preWrap)}>
                    {contact.address || "—"}
                  </td>
                  <td {...stylex.props(ui.td)}>
                    <div {...stylex.props(ui.actions)}>
                      <Link
                        {...stylex.props(ui.link, ui.smallLink)}
                        href={`/contacts/${contact.id}/edit`}
                      >
                        Edit
                      </Link>
                      <button
                        type="button"
                        {...stylex.props(
                          ui.nativeButton,
                          ui.textButton,
                          ui.danger,
                        )}
                        disabled={deletion.processing}
                        onClick={() => {
                          if (
                            window.confirm(
                              "Delete this saved contact? Existing invoices and drafts keep their copied recipient details.",
                            )
                          )
                            deletion.delete(`/contacts/${contact.id}`);
                        }}
                      >
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {!contacts.length && (
          <div {...stylex.props(ui.empty)}>
            <h2 {...stylex.props(ui.h2)}>
              {query
                ? "No matching contacts"
                : "Your common recipients belong here."}
            </h2>
            <p {...stylex.props(ui.paragraph)}>
              Add a name, organization, email and mailing address, then choose
              the contact from any invoice draft.
            </p>
          </div>
        )}
        <PaginationControls
          pagination={pagination}
          url="/contacts"
          query={query}
          only={["contacts", "pagination", "query"]}
        />
      </section>
    </>
  );
}
