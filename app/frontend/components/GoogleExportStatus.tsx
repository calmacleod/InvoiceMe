import * as stylex from "@stylexjs/stylex";
import type { GoogleExportProgress } from "../types";
import { colors, space } from "../styles/tokens.stylex";
import { ui } from "../styles/ui.stylex";

const steps = [
  ["validating", "Check Google destinations"],
  ["finalizing", "Finalize invoice"],
  ["document", "Save Google Doc"],
  ["pdf", "Save PDF"],
  ["ledger", "Update master ledger"],
] as const;
const time = new Intl.DateTimeFormat("en-CA", {
  hour: "numeric",
  minute: "2-digit",
  second: "2-digit",
});

export default function GoogleExportStatus({
  progress,
}: {
  progress: GoogleExportProgress;
}) {
  const current = steps.findIndex(([step]) => step === progress.step);
  const title = {
    queued: "Queued for Google",
    running: "Saving to Google…",
    retrying: "Waiting to retry Google",
    succeeded: "Google export completed",
    failed: "Google export needs attention",
  }[progress.status];
  return (
    <div aria-live="polite" role="status" {...stylex.props(styles.status)}>
      <strong {...stylex.props(ui.strong)}>{title}</strong>
      {progress.active && (
        <p {...stylex.props(ui.paragraph, ui.hint)}>
          You can leave this page. The export will continue.
        </p>
      )}
      <ol {...stylex.props(styles.steps)}>
        {steps.map(([step, label], index) => {
          const done = progress.status === "succeeded" || index < current;
          const active = index === current && progress.status !== "succeeded";
          return (
            <li
              key={step}
              aria-current={active ? "step" : undefined}
              {...stylex.props(styles.step, (done || active) && styles.reached)}
            >
              <span aria-hidden="true">{done ? "✓" : active ? "→" : "○"}</span>
              {label}
              {done && <span {...stylex.props(styles.srOnly)}>Complete</span>}
            </li>
          );
        })}
      </ol>
      {progress.attempts > 0 && (
        <p {...stylex.props(ui.paragraph, ui.hint)}>
          Attempt {progress.attempts} of {progress.max_attempts}
          {progress.retry_at && (
            <>
              {" "}
              · Next attempt around{" "}
              <time dateTime={progress.retry_at}>
                {time.format(new Date(progress.retry_at))}
              </time>
            </>
          )}
        </p>
      )}
      {progress.error && (
        <p {...stylex.props(ui.paragraph, styles.error)}>
          {progress.error}
          {progress.status === "failed" &&
            " Your invoice and completed steps are retained. Resolve the issue if needed, then retry below."}
        </p>
      )}
    </div>
  );
}

const styles = stylex.create({
  status: { marginBottom: space.lg },
  steps: {
    listStyle: "none",
    padding: 0,
    marginTop: space.md,
    marginBottom: space.md,
  },
  step: {
    display: "flex",
    alignItems: "center",
    gap: space.sm,
    paddingTop: space.xs,
    paddingBottom: space.xs,
    color: colors.subtle,
    fontSize: 12,
  },
  reached: { color: colors.accent, fontWeight: 600 },
  error: { color: colors.danger, fontSize: 12, overflowWrap: "anywhere" },
  srOnly: {
    position: "absolute",
    width: 1,
    height: 1,
    padding: 0,
    margin: -1,
    overflow: "hidden",
    clipPath: "inset(50%)",
    whiteSpace: "nowrap",
    borderWidth: 0,
  },
});
