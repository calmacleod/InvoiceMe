import { Head, useForm } from "@inertiajs/react";
import Link from "../../components/AppLink";
import { Heading, Search, PaginationControls } from "../../components/UI";
import type { DraftMetadata, Pagination } from "../../types";
import { workbench } from "../../components/DraftWorkbench.stylex";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../../styles/ui.stylex";

export default function Index({
  drafts,
  pagination,
  query,
}: {
  drafts: DraftMetadata[];
  pagination: Pagination;
  query: string;
}) {
  const deletion = useForm({});
  return (
    <>
      <Head title="Draft workbench" />
      <Heading
        title="Draft workbench"
        actions={
          <Link
            {...stylex.props(ui.link, ui.button, ui.primary)}
            href="/invoice_drafts"
            method="post"
            as="button"
          >
            + New draft
          </Link>
        }
      >
        Resume an invoice or start a new draft.
      </Heading>
      <section {...stylex.props(ui.card, ui.tableCard)}>
        <div {...stylex.props(ui.tableHeading)}>
          <h2 {...stylex.props(ui.h2)}>
            {pagination.total} {pagination.total === 1 ? "draft" : "drafts"} in
            progress
          </h2>
          <Search
            url="/invoice_drafts"
            query={query}
            label="Search drafts"
            perPage={pagination.per_page}
            only={["drafts", "pagination", "query"]}
          />
        </div>
        <div {...stylex.props(workbench.draftList)}>
          {drafts.map((draft) => (
            <article {...stylex.props(workbench.draftRow)} key={draft.id}>
              <div>
                <Link
                  {...stylex.props(ui.link)}
                  href={`/invoice_drafts/${draft.id}/edit`}
                >
                  <strong {...stylex.props(ui.strong)}>{draft.title}</strong>
                </Link>
                <small {...stylex.props(ui.small)}>
                  Saved {new Date(draft.updated_at).toLocaleString("en-CA")}
                </small>
              </div>
              <div {...stylex.props(ui.actions)}>
                <Link
                  {...stylex.props(ui.link, ui.smallLink)}
                  href={`/invoice_drafts/${draft.id}/edit`}
                >
                  Resume →
                </Link>
                {draft.invoice_group_id && (
                  <Link
                    {...stylex.props(ui.link, ui.smallLink)}
                    href={`/invoice_groups/${draft.invoice_group_id}`}
                  >
                    View group
                  </Link>
                )}
                <button
                  type="button"
                  {...stylex.props(ui.nativeButton, ui.textButton, ui.danger)}
                  disabled={deletion.processing}
                  onClick={() => {
                    if (
                      window.confirm(
                        "Remove this workbench and its autosaved edits? Any invoice already saved for preview is kept.",
                      )
                    )
                      deletion.delete(`/invoice_drafts/${draft.id}`);
                  }}
                >
                  Remove workbench
                </button>
              </div>
            </article>
          ))}
        </div>
        {!drafts.length && (
          <div {...stylex.props(ui.empty)}>
            <h2 {...stylex.props(ui.h2)}>
              {query ? "No matching drafts" : "No drafts this year"}
            </h2>
          </div>
        )}
        <PaginationControls
          pagination={pagination}
          url="/invoice_drafts"
          query={query}
          only={["drafts", "pagination", "query"]}
        />
      </section>
    </>
  );
}
