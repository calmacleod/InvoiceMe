import { Head } from "@inertiajs/react";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../../styles/ui.stylex";
import type { InvoiceGroupReference, Pagination } from "../../types";
import Link from "../../components/AppLink";
import { Heading, PaginationControls } from "../../components/UI";

export default function Index({
  groups,
  pagination,
}: {
  groups: (InvoiceGroupReference & {
    game_count: number;
    invoice_count: number;
    draft_count: number;
  })[];
  pagination: Pagination;
}) {
  return (
    <>
      <Head title="Invoice groups" />
      <Heading
        title="Invoice groups"
        actions={
          <Link {...stylex.props(ui.link, ui.button, ui.primary)} href="/games">
            Select games for a group
          </Link>
        }
      >
        Keep separate invoices for different payers together around the same
        Horizon games.
      </Heading>
      <section
        {...stylex.props(ui.card, ui.tableCard)}
        aria-label="Invoice groups"
      >
        {groups.length ? (
          <div {...stylex.props(ui.tableScroll)}>
            <table {...stylex.props(ui.table)}>
              <thead>
                <tr>
                  <th {...stylex.props(ui.th)}>Group</th>
                  <th {...stylex.props(ui.th, ui.numeric)}>Games</th>
                  <th {...stylex.props(ui.th, ui.numeric)}>Saved invoices</th>
                  <th {...stylex.props(ui.th, ui.numeric)}>Drafts</th>
                </tr>
              </thead>
              <tbody>
                {groups.map((group) => (
                  <tr {...stylex.props(ui.row)} key={group.id}>
                    <td {...stylex.props(ui.td)}>
                      <Link
                        {...stylex.props(ui.link, ui.strong)}
                        href={`/invoice_groups/${group.id}`}
                      >
                        {group.name}
                      </Link>
                    </td>
                    <td {...stylex.props(ui.td, ui.numeric)}>
                      {group.game_count}
                    </td>
                    <td {...stylex.props(ui.td, ui.numeric)}>
                      {group.invoice_count}
                    </td>
                    <td {...stylex.props(ui.td, ui.numeric)}>
                      {group.draft_count}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <p {...stylex.props(ui.empty)}>
            No invoice groups this year. Select games to start one.
          </p>
        )}
        {pagination.pages > 1 && (
          <PaginationControls
            url="/invoice_groups"
            pagination={pagination}
            query=""
            only={["groups", "pagination"]}
          />
        )}
      </section>
    </>
  );
}
