import { Head, useForm } from "@inertiajs/react";
import * as stylex from "@stylexjs/stylex";
import Link from "../../components/AppLink";
import { Field, Heading } from "../../components/UI";
import { money } from "../../lib/format";
import { ui } from "../../styles/ui.stylex";

type Preview = {
  first_cheque_number: string;
  preview_token: string;
  rows: {
    id: number;
    payment_number: number;
    official_name: string;
    net_cents: number;
    cheque_number: string;
    reviewed: boolean;
  }[];
};

export default function ChequeSequence({
  year,
  preview,
  preview_error,
}: {
  year: number;
  preview: Preview | null;
  preview_error: string | null;
}) {
  const form = useForm({
    first_cheque_number: preview?.first_cheque_number ?? "",
  });
  const recording = useForm({ preview_token: "" });
  const first = form.data.first_cheque_number.trim();
  const currentPreview =
    preview?.first_cheque_number === first ? preview : null;
  const needsReview = currentPreview?.rows.some((row) => !row.reviewed);

  return (
    <>
      <Head title="Assign cheque numbers" />
      <Link
        {...stylex.props(ui.link, ui.contextLink)}
        href="/official_payments"
      >
        ← Officials payments
      </Link>
      <Heading title="Assign cheque numbers">
        {year} · Payable officials awaiting a cheque number
      </Heading>
      <section {...stylex.props(ui.card)}>
        <form
          {...stylex.props(ui.inlineForm)}
          onSubmit={(event) => {
            event.preventDefault();
            if (first && !form.processing && !recording.processing)
              form.post("/official_payments/cheque_sequence");
          }}
        >
          <div {...stylex.props(ui.inlineField)}>
            <Field
              name="first_cheque_number"
              label="First cheque number"
              value={form.data.first_cheque_number}
              onChange={(value) => form.setData("first_cheque_number", value)}
              autoComplete="off"
              required
              maxLength={40}
            />
          </div>
          <button
            type="submit"
            {...stylex.props(ui.button, ui.primary)}
            disabled={!first || form.processing || recording.processing}
          >
            Preview sequence
          </button>
        </form>
        {preview_error && (
          <p {...stylex.props(ui.flash, ui.alert)} role="alert">
            {preview_error}
          </p>
        )}
      </section>
      {currentPreview && (
        <section {...stylex.props(ui.card, ui.tableCard)}>
          <div {...stylex.props(ui.tableHeading)}>
            <h2 {...stylex.props(ui.h2)}>Review cheque numbers</h2>
            <p {...stylex.props(ui.paragraph, ui.sectionHint)}>
              {needsReview
                ? "Earnings awaiting review stay editable after you assign the cheque numbers."
                : "Assigning these cheque numbers locks the reviewed earnings."}
            </p>
          </div>
          <div {...stylex.props(ui.tableScroll)}>
            <table {...stylex.props(ui.table)} aria-label="Proposed cheques">
              <thead>
                <tr>
                  <th {...stylex.props(ui.th)} scope="col">
                    Payment
                  </th>
                  <th {...stylex.props(ui.th)} scope="col">
                    Official
                  </th>
                  <th {...stylex.props(ui.th, ui.numeric)} scope="col">
                    Net earnings
                  </th>
                  <th {...stylex.props(ui.th)} scope="col">
                    Proposed cheque
                  </th>
                  <th {...stylex.props(ui.th)} scope="col">
                    Earnings review
                  </th>
                </tr>
              </thead>
              <tbody>
                {currentPreview.rows.map((row) => (
                  <tr key={row.id} {...stylex.props(ui.row)}>
                    <td {...stylex.props(ui.td)}>#{row.payment_number}</td>
                    <th {...stylex.props(ui.td)} scope="row">
                      <Link
                        {...stylex.props(ui.link, ui.strong)}
                        href={`/official_payments/${row.id}/edit`}
                      >
                        {row.official_name}
                      </Link>
                    </th>
                    <td {...stylex.props(ui.td, ui.numeric)}>
                      {money(row.net_cents)}
                    </td>
                    <td {...stylex.props(ui.td, ui.strong)}>
                      {row.cheque_number}
                    </td>
                    <td {...stylex.props(ui.td)}>
                      {row.reviewed ? "Reviewed" : "Needs review"}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <form
            {...stylex.props(ui.tableHeading, ui.formActions)}
            onSubmit={(event) => {
              event.preventDefault();
              if (form.processing || recording.processing) return;
              recording.transform(() => ({
                preview_token: currentPreview.preview_token,
              }));
              recording.patch("/official_payments/cheque_sequence");
            }}
          >
            <button
              type="submit"
              {...stylex.props(ui.button, ui.primary)}
              disabled={form.processing || recording.processing}
            >
              Assign {currentPreview.rows.length} cheque{" "}
              {currentPreview.rows.length === 1 ? "number" : "numbers"}
            </button>
          </form>
        </section>
      )}
    </>
  );
}
