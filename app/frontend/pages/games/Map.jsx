import { Head, Link, useForm } from "@inertiajs/react";
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
  const form = useForm({
    mapping: {
      ...Object.fromEntries(
        fields.map((field) => [field, mapping[field] ?? ""]),
      ),
      official_columns: columns,
    },
    date_format: "%m/%d/%Y",
  });
  const setMapping = (key, value) =>
    form.setData("mapping", { ...form.data.mapping, [key]: value });
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
        <div className="flash notice">
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
        <section className="card">
          <div className="form-grid">
            {fields.map((field) => (
              <div key={field}>
                <label htmlFor={`mapping-${field}`}>
                  {names[field] ?? field}
                  {required.includes(field) ? " *" : " (optional)"}
                </label>
                <select
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
              <label htmlFor="date_format">Date format for non-ISO dates</label>
              <select
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
          <p className="hint">
            For one row per official, fees are summed by game number. For one
            row per game, map the game's total fee. Avoid mapping a repeated
            game total on every official's row. Unmapped columns remain
            available in Source details.
          </p>
          <details>
            <summary>
              My export has separate columns for each officiating position
            </summary>
            <p className="hint">
              Match each name column, position, and fee column. Leave the single
              Officials field empty. A mapped per-row fee supplies the game
              total; otherwise position fees are summed.
            </p>
            {Object.entries(form.data.mapping.official_columns).map(
              ([index, assignment]) => (
                <div className="form-grid" key={index}>
                  {[
                    ["name", "name"],
                    ["amount", "fee"],
                    ["position", "position"],
                  ].map(([key, label]) => (
                    <div key={key}>
                      <label htmlFor={`official-${index}-${key}`}>
                        Official {Number(index) + 1} {label} column
                      </label>
                      <select
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
        <section className="card table-card">
          <div className="table-heading">
            <h2>A peek at your file</h2>
          </div>
          <div className="table-scroll">
            <table>
              <thead>
                <tr>
                  {headers.map((header) => (
                    <th key={header}>{header}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {rows.map((row, i) => (
                  <tr key={i}>
                    {row.map((value, j) => (
                      <td key={j}>{value}</td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
        <div className="form-actions">
          <Link href="/games/new" className="button">
            Start over
          </Link>
          <button className="button primary" disabled={form.processing}>
            Review import →
          </button>
        </div>
      </form>
    </>
  );
}
