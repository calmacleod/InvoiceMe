import Link from "../../components/AppLink";
import type {
  ImportField,
  ImportMapping,
  MappingForm,
  ImportInfo,
} from "../../types";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../../styles/ui.stylex";
import { Head, useForm } from "@inertiajs/react";
import { Errors, Heading } from "../../components/UI";
const names = {
  external_id: "Game number",
  code: "Game code",
  date: "Date",
  time: "Time",
  home_team: "Home team",
  away_team: "Away team",
  location: "Location",
  officials: "Officials",
  fees: "Official fees per row",
};
export default function Map({
  headers,
  rows,
  row_count,
  info,
  mapping,
  fields,
  required,
}: {
  headers: string[];
  rows: (string | null)[][];
  row_count: number;
  info: ImportInfo;
  mapping: ImportMapping;
  fields: ImportField[];
  required: ImportField[];
}) {
  const columns = Object.fromEntries(
    Array.from(
      {
        length: Math.max(8, Object.keys(mapping.official_columns ?? {}).length),
      },
      (_, index) => [
        String(index),
        mapping.official_columns?.[index] ?? {
          name: "",
          amount: "",
          position: "",
        },
      ],
    ),
  );
  const form = useForm<{ mapping: MappingForm; date_format: string }>({
    mapping: {
      ...(Object.fromEntries(
        fields.map((field) => [field, mapping[field] ?? ""]),
      ) as Record<ImportField, string>),
      official_columns: columns,
    },
    date_format: "%m/%d/%Y",
  });
  const setMapping = <Key extends keyof MappingForm>(
    key: Key,
    value: MappingForm[Key],
  ) =>
    form.setData("mapping", {
      ...form.data.mapping,
      [key]: value,
    });
  const options = (
    <>
      <option value="">Skip this field</option>
      {headers.map((header) => (
        <option key={header} value={header}>
          {header}
        </option>
      ))}
    </>
  );
  return (
    <>
      <Head title="Match columns" />
      <Heading eyebrow="IMPORT · STEP 2 OF 3" title="Match your columns">
        We found {row_count} rows. Tell us where to find each detail.
      </Heading>
      {info.format === "horizon_master_fees" && (
        <div {...stylex.props(ui.flash)}>
          Horizon master-fees export detected. All official names, positions,
          and fees are matched automatically. {info.skipped_meetings} meeting
          entries are excluded. Fees do not establish that an official has been
          paid.
        </div>
      )}
      <form
        onSubmit={(event) => {
          event.preventDefault();
          form.post("/games/preview");
        }}
      >
        <Errors errors={form.errors} />
        <section {...stylex.props(ui.card)}>
          <div {...stylex.props(ui.formGrid)}>
            {fields.map((field) => (
              <div key={field}>
                <label {...stylex.props(ui.label)} htmlFor={`mapping-${field}`}>
                  {names[field] ?? field}
                  {required.includes(field) ? " *" : " (optional)"}
                </label>
                <select
                  {...stylex.props(ui.input)}
                  id={`mapping-${field}`}
                  value={form.data.mapping[field]}
                  onChange={(event) => setMapping(field, event.target.value)}
                  required={required.includes(field)}
                >
                  {options}
                </select>
              </div>
            ))}
            <div>
              <label {...stylex.props(ui.label)} htmlFor="date_format">
                Date format for non-ISO dates
              </label>
              <select
                {...stylex.props(ui.input)}
                id="date_format"
                value={form.data.date_format}
                onChange={(event) =>
                  form.setData("date_format", event.target.value)
                }
              >
                <option value="%m/%d/%Y">Month / Day / Year</option>
                <option value="%d/%m/%Y">Day / Month / Year</option>
                <option value="%Y-%m-%d">Year-Month-Day</option>
              </select>
            </div>
          </div>
          <p {...stylex.props(ui.paragraph, ui.hint)}>
            For one row per official, fees are summed by game number. For one
            row per game, map the game's total fee. Avoid mapping a repeated
            game total on every official's row. Unmapped columns remain
            available in Source details.
          </p>
          <details {...stylex.props(ui.details)}>
            <summary {...stylex.props(ui.summary)}>
              My export has separate columns for each officiating position
            </summary>
            <p {...stylex.props(ui.paragraph, ui.hint)}>
              Match each name column, position, and fee column. Leave the single
              Officials field empty. A mapped per-row fee supplies the game
              total; otherwise position fees are summed.
            </p>
            {Object.entries(form.data.mapping.official_columns).map(
              ([index, assignment]) => (
                <div {...stylex.props(ui.formGrid)} key={index}>
                  {(
                    [
                      ["name", "name"],
                      ["amount", "fee"],
                      ["position", "position"],
                    ] as const
                  ).map(([key, label]) => (
                    <div key={key}>
                      <label
                        {...stylex.props(ui.label)}
                        htmlFor={`official-${index}-${key}`}
                      >
                        Official {Number(index) + 1} {label} column
                      </label>
                      <select
                        {...stylex.props(ui.input)}
                        id={`official-${index}-${key}`}
                        value={assignment[key] ?? ""}
                        onChange={(event) =>
                          setMapping("official_columns", {
                            ...form.data.mapping.official_columns,
                            [index]: {
                              ...assignment,
                              [key]: event.target.value,
                            },
                          })
                        }
                      >
                        {options}
                      </select>
                    </div>
                  ))}
                </div>
              ),
            )}
          </details>
        </section>
        <section {...stylex.props(ui.card, ui.tableCard)}>
          <div {...stylex.props(ui.tableHeading)}>
            <h2 {...stylex.props(ui.h2)}>A peek at your file</h2>
          </div>
          <div {...stylex.props(ui.tableScroll)}>
            <table {...stylex.props(ui.table)}>
              <thead>
                <tr>
                  {headers.map((header) => (
                    <th {...stylex.props(ui.th)} key={header}>
                      {header}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {rows.map((row, i) => (
                  <tr key={i}>
                    {row.map((value, j) => (
                      <td {...stylex.props(ui.td)} key={j}>
                        {value}
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
        <div {...stylex.props(ui.formActions)}>
          <Link {...stylex.props(ui.link, ui.button)} href="/games/new">
            Start over
          </Link>
          <button
            {...stylex.props(ui.nativeButton, ui.button, ui.primary)}
            disabled={form.processing}
          >
            Review import →
          </button>
        </div>
      </form>
    </>
  );
}
