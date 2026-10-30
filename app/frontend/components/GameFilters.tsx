import { useEffect, useState } from "react";
import type { GameFilters as Values, GameFilterChoices } from "../types";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../styles/ui.stylex";
import { browserStyles as styles } from "./GameBrowser.stylex";
import { Field } from "./UI";
import SearchableMultiSelect from "./SearchableMultiSelect";

const labels: [Exclude<keyof Values, keyof GameFilterChoices>, string][] = [
  ["q", "Search games"],
  ["location", "Venue"],
  ["official", "Official name"],
  ["date_from", "From date"],
  ["date_to", "To date"],
];
const multiLabels: [keyof GameFilterChoices, string][] = [
  ["code", "Game code"],
  ["home_team", "Home team"],
  ["away_team", "Away team"],
];
export const emptyGameFilters: Values = {
  q: "",
  home_team: [],
  away_team: [],
  code: [],
  location: "",
  official: "",
  date_from: "",
  date_to: "",
  link_status: "",
};

export default function GameFilters({
  applied,
  choices,
  errors,
  busy,
  onApply,
  id,
  collapsible = false,
}: {
  applied: Values;
  choices: GameFilterChoices;
  errors: string[];
  busy: boolean;
  onApply: (values: Values) => void;
  id: string;
  collapsible?: boolean;
}) {
  const [values, setValues] = useState(applied);
  const active = Object.values(applied).filter((value) =>
    Array.isArray(value) ? value.length > 0 : Boolean(value),
  ).length;
  const [expanded, setExpanded] = useState(!collapsible || active === 0);
  useEffect(() => setValues(applied), [applied]);
  useEffect(() => {
    if (errors.length) setExpanded(true);
  }, [errors]);
  const apply = (next: Values) => {
    onApply(next);
    if (collapsible) setExpanded(false);
  };
  const fields = (
    <fieldset
      {...stylex.props(styles.filters)}
      disabled={busy}
      onKeyDown={(event) => {
        if (
          event.key === "Enter" &&
          event.target instanceof HTMLInputElement &&
          !event.nativeEvent.isComposing
        ) {
          event.preventDefault();
          apply(values);
        }
      }}
    >
      <legend {...stylex.props(ui.label)}>Filter games</legend>
      <div {...stylex.props(styles.filterGrid)}>
        {multiLabels.map(([key, label]) => (
          <SearchableMultiSelect
            key={key}
            id={`${id}-${key}`}
            label={label}
            options={choices[key]}
            value={values[key]}
            onChange={(value) =>
              setValues((previous) => ({ ...previous, [key]: value }))
            }
          />
        ))}
        {labels.map(([key, label]) => (
          <Field
            key={key}
            name={`${id}-${key}`}
            label={label}
            value={values[key]}
            type={key.startsWith("date_") ? "date" : "search"}
            placeholder={key === "q" ? "Game ID, team, code or venue…" : "Any"}
            onChange={(value) =>
              setValues((previous) => ({ ...previous, [key]: value }))
            }
          />
        ))}
        <div>
          <label {...stylex.props(ui.label)} htmlFor={`${id}-link-status`}>
            Invoice link status
          </label>
          <select
            {...stylex.props(ui.input)}
            id={`${id}-link-status`}
            value={values.link_status}
            onChange={(event) =>
              setValues((previous) => ({
                ...previous,
                link_status: event.target.value,
              }))
            }
          >
            <option value="">All games</option>
            <option value="unlinked">
              Not invoiced or selected in a workbench
            </option>
            <option value="linked">Invoiced or selected in a workbench</option>
            <option value="invoiced">
              Invoiced or linked to a saved invoice
            </option>
            <option value="workbench">Selected in a workbench</option>
          </select>
        </div>
      </div>
      <div {...stylex.props(styles.filterActions)}>
        <button
          type="button"
          {...stylex.props(ui.nativeButton, ui.button, ui.primary)}
          onClick={() => apply(values)}
        >
          Apply filters
        </button>
        <button
          type="button"
          {...stylex.props(ui.nativeButton, ui.button)}
          onClick={() => {
            setValues(emptyGameFilters);
            apply(emptyGameFilters);
          }}
        >
          Clear filters
        </button>
        <span {...stylex.props(ui.hint)}>
          Select any matching codes or teams. Venue and official filters match
          part of the name.
        </span>
      </div>
      {errors.length > 0 && (
        <ul {...stylex.props(ui.danger)} role="alert">
          {errors.map((error) => (
            <li key={error}>{error}</li>
          ))}
        </ul>
      )}
    </fieldset>
  );
  return collapsible ? (
    <details
      open={expanded}
      onToggle={(event) => setExpanded(event.currentTarget.open)}
    >
      <summary {...stylex.props(styles.filterSummary)}>
        Filters · {active} active · change
      </summary>
      {fields}
    </details>
  ) : (
    fields
  );
}
