import { Head, useForm } from "@inertiajs/react";
import * as stylex from "@stylexjs/stylex";
import Link from "../../components/AppLink";
import {
  Badge,
  Heading,
  PaginationControls,
  Search,
  Section,
} from "../../components/UI";
import { date, money } from "../../lib/format";
import { ui } from "../../styles/ui.stylex";
import type {
  InvoiceGroupReference,
  InvoiceSummary,
  Pagination,
} from "../../types";

type GameReference = {
  id: number;
  external_id: string;
  date: string;
  matchup: string;
};

type AttachmentReview = {
  invoice: InvoiceSummary;
  shared_game_count: number;
  games_added: GameReference[];
  games_removed: GameReference[];
  blocked_reason: string | null;
  token: string;
};

type Props = { group: InvoiceGroupReference } & (
  | { review: AttachmentReview }
  | {
      review: null;
      invoices: InvoiceSummary[];
      pagination: Pagination;
      query: string;
    }
);

const listProps = ["invoices", "pagination", "query"];

export default function AddExisting(props: Props) {
  const { group, review } = props;
  const groupUrl = `/invoice_groups/${group.id}`;
  const url = `${groupUrl}/add_existing`;
  return (
    <>
      <Head title="Add existing invoice" />
      <Heading
        title="Add existing invoice"
        actions={
          <Link {...stylex.props(ui.link, ui.button)} href={groupUrl}>
            Back to group
          </Link>
        }
      >
        {group.name}
      </Heading>
      {review ? (
        <Review key={review.invoice.id} review={review} groupUrl={groupUrl} />
      ) : (
        <section
          {...stylex.props(ui.card, ui.tableCard)}
          aria-label="Invoices available to add"
        >
          <div {...stylex.props(ui.tableHeading)}>
            <Search
              url={url}
              query={props.query}
              label="Search invoices"
              perPage={props.pagination.per_page}
              only={listProps}
            />
          </div>
          {props.invoices.length > 0 ? (
            <div {...stylex.props(ui.tableScroll)}>
              <table {...stylex.props(ui.table)}>
                <thead>
                  <tr>
                    <th {...stylex.props(ui.th)}>Invoice</th>
                    <th {...stylex.props(ui.th)}>Status</th>
                    <th {...stylex.props(ui.th, ui.numeric)}>Total (CAD)</th>
                    <th {...stylex.props(ui.th)}>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {props.invoices.map((invoice) => (
                    <tr key={invoice.id}>
                      <td {...stylex.props(ui.td)}>
                        <strong {...stylex.props(ui.strong)}>
                          {invoice.number} · {invoice.recipient}
                        </strong>
                        <small {...stylex.props(ui.small)}>
                          {invoice.description}
                        </small>
                      </td>
                      <td {...stylex.props(ui.td)}>
                        <Badge status={invoice.status} />
                      </td>
                      <td {...stylex.props(ui.td, ui.numeric)}>
                        {money(invoice.total_cents)}
                      </td>
                      <td {...stylex.props(ui.td)}>
                        <Link
                          {...stylex.props(ui.link, ui.button)}
                          href={url}
                          data={{ invoice_id: invoice.id }}
                          aria-label={`Review ${invoice.number}`}
                        >
                          Review
                        </Link>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <p {...stylex.props(ui.empty)}>
              {props.query
                ? "No matching invoices."
                : "No ungrouped saved invoices for this year."}
            </p>
          )}
          {props.pagination.total > 0 && (
            <PaginationControls
              url={url}
              pagination={props.pagination}
              query={props.query}
              only={listProps}
            />
          )}
        </section>
      )}
    </>
  );
}

function Review({
  review,
  groupUrl,
}: {
  review: AttachmentReview;
  groupUrl: string;
}) {
  const {
    invoice,
    games_added,
    games_removed,
    blocked_reason,
    shared_game_count,
    token,
  } = review;
  const form = useForm({ invoice_id: invoice.id });
  const gameChanges = games_added.length > 0 || games_removed.length > 0;
  return (
    <Section title={`${invoice.number} · ${invoice.recipient}`}>
      <div {...stylex.props(ui.groupFields)}>
        <div {...stylex.props(ui.actions)}>
          <Badge status={invoice.status} />
          <strong>{money(invoice.total_cents)}</strong>
        </div>
        {blocked_reason ? (
          <p role="status">{blocked_reason}</p>
        ) : gameChanges ? (
          <>
            <p>
              This invoice will use the group’s {shared_game_count} shared{" "}
              {shared_game_count === 1 ? "game" : "games"}.
            </p>
            <GameChanges label="Games to add" games={games_added} />
            <GameChanges
              label="Games to remove from this invoice"
              games={games_removed}
            />
          </>
        ) : (
          <p>This invoice already links to the group’s games.</p>
        )}
        <form
          {...stylex.props(ui.actions)}
          onSubmit={(event) => {
            event.preventDefault();
            form.transform((data) => ({ ...data, review_token: token }));
            form.post(`${groupUrl}/attach_invoice`);
          }}
        >
          {!blocked_reason && (
            <button
              type="submit"
              {...stylex.props(ui.nativeButton, ui.button, ui.primary)}
              disabled={form.processing}
            >
              {gameChanges
                ? "Add invoice with shared games"
                : "Add invoice to group"}
            </button>
          )}
          <Link
            {...stylex.props(ui.link, ui.button)}
            href={`${groupUrl}/add_existing`}
          >
            Choose another invoice
          </Link>
        </form>
      </div>
    </Section>
  );
}

function GameChanges({
  label,
  games,
}: {
  label: string;
  games: GameReference[];
}) {
  if (games.length === 0) return null;

  return (
    <details>
      <summary>
        {label} ({games.length})
      </summary>
      <ul>
        {games.map((game) => (
          <li key={game.id}>
            #{game.external_id} · {date(game.date)} · {game.matchup}
          </li>
        ))}
      </ul>
    </details>
  );
}
