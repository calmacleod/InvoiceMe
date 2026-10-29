import { Head, useForm } from "@inertiajs/react";
import { Errors, Heading } from "../../components/UI";

export default function Upload() {
  const form = useForm({ file: null });
  return (
    <>
      <Head title="Import games" />
      <Heading eyebrow="HORIZON → INVOICEME" title="Import your games">
        A quick upload today. Less manual work for every invoice after.
      </Heading>
      <div className="import-steps">
        <strong>01 Upload</strong>
        <span>→ 02 Match columns</span>
        <span>→ 03 Review & import</span>
      </div>
      <section className="card upload-card">
        <span className="empty-icon">↑</span>
        <h2>Bring your Horizon export</h2>
        <p>CSV or XLSX · up to 10 MB · up to 20,000 rows</p>
        <Errors errors={form.errors} />
        <form
          onSubmit={(event) => {
            event.preventDefault();
            form.post("/games/upload", { forceFormData: true });
          }}
        >
          <label htmlFor="file">
            Choose a master schedule or payroll export
          </label>
          <input
            id="file"
            type="file"
            accept=".csv,.xlsx"
            required
            onChange={(event) =>
              form.setData("file", event.target.files[0] ?? null)
            }
          />
          {form.progress && (
            <p role="status">Uploading {form.progress.percentage}%</p>
          )}
          <button className="button primary full" disabled={form.processing}>
            Continue to column matching →
          </button>
        </form>
      </section>
      <div className="two-cards">
        <section className="card">
          <h3>Use the whole season</h3>
          <p>
            Set the date and game filters in Horizon before exporting. Include
            the game number, date, code, officials, and fees where available.
          </p>
          <a href="/games/sample" className="small-link">
            Download example CSV ↗
          </a>
        </section>
        <section className="card">
          <h3>Safe to import again</h3>
          <p>
            Games are matched by game number within each year. Importing a newer
            export updates those games without adding duplicates. Other games
            remain in place.
          </p>
        </section>
      </div>
    </>
  );
}
