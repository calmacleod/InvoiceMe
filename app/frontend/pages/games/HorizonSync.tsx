import Link from "../../components/AppLink";
import * as stylex from "@stylexjs/stylex";
import { Head, router, useForm } from "@inertiajs/react";
import { useEffect } from "react";
import { Heading, Stat } from "../../components/UI";
import { ui } from "../../styles/ui.stylex";
import { money } from "../../lib/format";

type Official = {
  name: string;
  position?: string | null;
  fee_cents: number | null;
};
type Change = { field: string; before: unknown; after: unknown };
type Row = {
  external_id: string;
  date: string;
  matchup: string;
  status: "new" | "changed" | "unchanged";
  linked: boolean;
  changes: Change[];
};
type Sync = {
  id: number;
  status: string;
  error: string | null;
  pages_fetched: number;
  total_pages: number | null;
  expired: boolean;
  rows: Row[];
};

function value(field: string, input: unknown): string {
  if (field === "fees_cents" && typeof input === "number") return money(input);
  if (field === "officials" && Array.isArray(input)) {
    return (
      (input as Official[])
        .map(
          (person) =>
            `${person.name}${person.position ? ` (${person.position})` : ""}: ${person.fee_cents == null ? "no fee" : money(person.fee_cents)}`,
        )
        .join("; ") || "None"
    );
  }
  return input == null || input === "" ? "—" : String(input);
}

export default function HorizonSync({ sync }: { sync: Sync }) {
  const form = useForm({});
  useEffect(() => {
    if (!["queued", "running"].includes(sync.status)) return;
    const timer = window.setInterval(() => {
      if (!document.hidden) router.reload({ only: ["sync", "flash"] });
    }, 3000);
    return () => window.clearInterval(timer);
  }, [sync.status]);
  const counts = (status: Row["status"]) =>
    sync.rows.filter((row) => row.status === status).length;
  return (
    <>
      <Head title="Horizon sync" />
      <Heading title="Review Horizon sync">
        Games are only updated when you apply this review. Existing invoice
        links, invoicing marks and CSV source details are retained.
      </Heading>
      {["queued", "running"].includes(sync.status) && (
        <p {...stylex.props(ui.paragraph)}>
          Reading Horizon schedule: {sync.pages_fetched}
          {sync.total_pages != null ? ` of ${sync.total_pages}` : ""} pages
          complete. This page refreshes automatically.
        </p>
      )}
      {sync.status === "failed" && (
        <div {...stylex.props(ui.flash, ui.alert)} role="alert">
          {sync.error}
        </div>
      )}
      {sync.status === "applied" && (
        <div {...stylex.props(ui.flash)}>This sync was applied.</div>
      )}
      {sync.status === "ready" && (
        <>
          <div {...stylex.props(ui.stats)}>
            <Stat label="New" value={counts("new")} />
            <Stat label="Changed" value={counts("changed")} />
            <Stat label="Unchanged" value={counts("unchanged")} />
          </div>
          <p {...stylex.props(ui.paragraph)}>
            Fees include the assignment fee, travel, per diem, tolls and other
            fees. Deductions are not included. Horizon does not supply Paid By
            Team in this response, so imported values are retained and new games
            leave it unknown. Games absent from this response are not deleted.
          </p>
          {sync.expired && (
            <div {...stylex.props(ui.flash, ui.alert)}>
              This review expired. Start a new sync.
            </div>
          )}
          <section {...stylex.props(ui.card, ui.tableCard)}>
            <div {...stylex.props(ui.tableScroll)}>
              <table {...stylex.props(ui.table)}>
                <thead>
                  <tr>
                    <th {...stylex.props(ui.th)}>Game</th>
                    <th {...stylex.props(ui.th)}>Date and matchup</th>
                    <th {...stylex.props(ui.th)}>Result</th>
                    <th {...stylex.props(ui.th)}>Changes</th>
                  </tr>
                </thead>
                <tbody>
                  {sync.rows.map((row) => (
                    <tr {...stylex.props(ui.row)} key={row.external_id}>
                      <td {...stylex.props(ui.td)}>{row.external_id}</td>
                      <td {...stylex.props(ui.td)}>
                        {row.date}
                        <br />
                        {row.matchup}
                      </td>
                      <td {...stylex.props(ui.td)}>
                        {row.status}
                        {row.linked ? " · linked to invoice" : ""}
                      </td>
                      <td {...stylex.props(ui.td)}>
                        {row.changes.map((change) => (
                          <div key={change.field}>
                            <strong>{change.field.replaceAll("_", " ")}</strong>
                            : {value(change.field, change.before)} →{" "}
                            {value(change.field, change.after)}
                          </div>
                        ))}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>
          <div {...stylex.props(ui.formActions, ui.sticky)}>
            <Link
              {...stylex.props(ui.link, ui.button)}
              href={`/horizon_game_syncs/${sync.id}`}
              as="button"
              method="delete"
            >
              Discard review
            </Link>
            <button
              {...stylex.props(ui.nativeButton, ui.button, ui.primary)}
              disabled={sync.expired || form.processing}
              onClick={() => form.post(`/horizon_game_syncs/${sync.id}/apply`)}
            >
              Apply sync
            </button>
          </div>
        </>
      )}
      {sync.status !== "ready" && (
        <Link {...stylex.props(ui.link, ui.button)} href="/games">
          Back to games
        </Link>
      )}
    </>
  );
}
