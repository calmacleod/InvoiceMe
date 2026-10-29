import * as stylex from "@stylexjs/stylex";
import { ui } from "../../styles/ui.stylex";
import { Head, useForm } from "@inertiajs/react";
import { Errors, Heading } from "../../components/UI";
export default function Upload() {
  const form = useForm<{ file: File | null }>({ file: null });
  return (
    <>
      <Head title="Import games" />
      <Heading eyebrow="HORIZON → INVOICEME" title="Import your games">
        A quick upload today. Less manual work for every invoice after.
      </Heading>
      <div {...stylex.props(ui.importSteps)}>
        <strong {...stylex.props(ui.strong)}>01 Upload</strong>
        <span>→ 02 Match columns</span>
        <span>→ 03 Review & import</span>
      </div>
      <section {...stylex.props(ui.card, ui.uploadCard)}>
        <span {...stylex.props(ui.emptyIcon)}>↑</span>
        <h2 {...stylex.props(ui.h2)}>Bring your Horizon export</h2>
        <p {...stylex.props(ui.paragraph)}>
          CSV or XLSX · up to 10 MB · up to 20,000 rows
        </p>
        <Errors errors={form.errors} />
        <form
          {...stylex.props(ui.uploadForm)}
          onSubmit={(event) => {
            event.preventDefault();
            form.post("/games/upload", {
              forceFormData: true,
            });
          }}
        >
          <label {...stylex.props(ui.label)} htmlFor="file">
            Choose a master schedule or payroll export
          </label>
          <input
            {...stylex.props(ui.input)}
            id="file"
            type="file"
            accept=".csv,.xlsx"
            required
            onChange={(event) =>
              form.setData("file", event.target.files?.[0] ?? null)
            }
          />
          {form.progress && (
            <p {...stylex.props(ui.paragraph)} role="status">
              Uploading {form.progress.percentage}%
            </p>
          )}
          <button
            {...stylex.props(
              ui.nativeButton,
              ui.submit,
              ui.button,
              ui.primary,
              ui.full,
            )}
            disabled={form.processing}
          >
            Continue to column matching →
          </button>
        </form>
      </section>
      <div {...stylex.props(ui.twoCards)}>
        <section {...stylex.props(ui.card)}>
          <h3 {...stylex.props(ui.h3)}>Use the whole season</h3>
          <p {...stylex.props(ui.paragraph)}>
            Set the date and game filters in Horizon before exporting. Include
            the game number, date, code, officials, and fees where available.
          </p>
          <a {...stylex.props(ui.link, ui.smallLink)} href="/games/sample">
            Download example CSV ↗
          </a>
        </section>
        <section {...stylex.props(ui.card)}>
          <h3 {...stylex.props(ui.h3)}>Safe to import again</h3>
          <p {...stylex.props(ui.paragraph)}>
            Games are matched by game number within each year. Importing a newer
            export updates those games without adding duplicates. Other games
            remain in place.
          </p>
        </section>
      </div>
    </>
  );
}
