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
        eyebrow="ROOM FOR WORK IN PROGRESS"
        title="Draft workbench."
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
        Work on several invoices at once. Every edit is saved automatically.
      </Heading>
      <section {...stylex.props(ui.card)}>
        <div {...stylex.props(ui.tableHeading)}>
          <h2 {...stylex.props(ui.h2)}>
            {pagination.total} drafts in progress
          </h2>
          <Search
            url="/invoice_drafts"
            query={query}
            label="Search drafts"
            only={["drafts", "pagination", "query"]}
          />
        </div>
        <div {...stylex.props(workbench.grid)}>
          {drafts.map((draft) => (
            <article {...stylex.props(workbench.draft)} key={draft.id}>
              <span {...stylex.props(workbench.caption)}>AUTOSAVED DRAFT</span>
              <Link
                {...stylex.props(ui.link)}
                href={`/invoice_drafts/${draft.id}/edit`}
              >
                <strong {...stylex.props(ui.strong)}>{draft.title}</strong>
              </Link>
              <small {...stylex.props(ui.small)}>
                Saved {new Date(draft.updated_at).toLocaleString("en-CA")}
              </small>
              <div {...stylex.props(ui.actions)}>
                <Link
                  {...stylex.props(ui.link, ui.smallLink)}
                  href={`/invoice_drafts/${draft.id}/edit`}
                >
                  Resume →
                </Link>
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
              {query ? "No matching drafts" : "Your next idea can start here."}
            </h2>
            <p {...stylex.props(ui.paragraph)}>
              Start a draft now. Finish the details whenever you're ready.
            </p>
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
