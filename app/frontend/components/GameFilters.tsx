import { useEffect, useId, useState } from "react";
import type { GameFilters as Values, GameFilterChoices } from "../types";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../styles/ui.stylex";
import { browserStyles as styles } from "./GameBrowser.stylex";
import { Field } from "./UI";
import SearchableMultiSelect from "./SearchableMultiSelect";

const textFields = [
  ["location", "Venue"],
  ["official", "Official name"],
  ["date_from", "From date"],
  ["date_to", "To date"],
] as const;
const choiceFields = [
  ["code", "Game code"],
  ["home_team", "Home team"],
  ["away_team", "Away team"],
] as const;
const statuses = {
  unlinked: "Not invoiced or selected in a workbench",
  linked: "Invoiced or selected in a workbench",
  invoiced: "Invoiced or linked to a saved invoice",
  workbench: "Selected in a workbench",
};

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

const filterLabels = [
  ...choiceFields,
  ...textFields,
  ["link_status", "Invoice status"],
] as const;

export default function GameFilters({
  applied,
  choices,
  errors,
  busy,
  onApply,
  id,
}: {
  applied: Values;
  choices: GameFilterChoices;
  errors: string[];
  busy: boolean;
  onApply: (values: Values) => void;
  id: string;
}) {
  const advancedId = useId();
  const [values, setValues] = useState(applied);
  const [expanded, setExpanded] = useState(false);
  const active = filterLabels.filter(([key]) => applied[key].length > 0);

  useEffect(() => setValues(applied), [applied]);
  useEffect(() => {
    if (errors.length) setExpanded(true);
  }, [errors]);

  function apply(next: Values) {
    if (busy) return;
    setValues(next);
    setExpanded(false);
    onApply(next);
  }

  return (
    <fieldset
      {...stylex.props(styles.filters)}
      disabled={busy}
      onKeyDown={(event) => {
        if (
          event.key === "Enter" &&
          !event.defaultPrevented &&
          event.target instanceof HTMLInputElement &&
          !event.nativeEvent.isComposing
        ) {
          event.preventDefault();
          apply(values);
        }
      }}
    >
      <legend {...stylex.props(ui.srOnly)}>Filter games</legend>
      <div {...stylex.props(styles.quickFilters)}>
        <input
          {...stylex.props(ui.input, styles.filterSearch)}
          id={`${id}-q`}
          type="search"
          aria-label="Search games"
          placeholder="Game ID, team, code or venue"
          value={values.q}
          onChange={(event) => setValues({ ...values, q: event.target.value })}
        />
        {!expanded && (
          <button
            type="button"
            {...stylex.props(ui.nativeButton, ui.button, ui.primary)}
            onClick={() => apply(values)}
          >
            Apply filters
          </button>
        )}
        <button
          type="button"
          {...stylex.props(ui.nativeButton, ui.button)}
          aria-expanded={expanded}
          aria-controls={advancedId}
          onClick={() => setExpanded(!expanded)}
        >
          {expanded ? "Hide filters" : "More filters"}
          {active.length > 0 ? ` (${active.length})` : ""}
        </button>
        {(active.length > 0 || applied.q || expanded) && (
          <button
            type="button"
            {...stylex.props(
              ui.nativeButton,
              ui.textButton,
              styles.clearFilters,
            )}
            onClick={() => apply(emptyGameFilters)}
          >
            Clear filters
          </button>
        )}
      </div>
      <div id={advancedId} hidden={!expanded}>
        {expanded && (
          <>
            <div {...stylex.props(styles.filterGrid, styles.extraFilters)}>
              {choiceFields.map(([key, label]) => (
                <SearchableMultiSelect
                  key={key}
                  id={`${id}-${key}`}
                  label={label}
                  options={choices[key]}
                  value={values[key]}
                  disabled={busy}
                  onChange={(value) =>
                    setValues((previous) => ({ ...previous, [key]: value }))
                  }
                />
              ))}
              {textFields.map(([key, label]) => (
                <Field
                  key={key}
                  name={`${id}-${key}`}
                  label={label}
                  value={values[key]}
                  type={key.startsWith("date_") ? "date" : "search"}
                  onChange={(value) =>
                    setValues((previous) => ({ ...previous, [key]: value }))
                  }
                />
              ))}
              <div>
                <label
                  {...stylex.props(ui.label)}
                  htmlFor={`${id}-link-status`}
                >
                  Invoice link status
                </label>
                <select
                  {...stylex.props(ui.input)}
                  id={`${id}-link-status`}
                  value={values.link_status}
                  onChange={(event) =>
                    setValues({ ...values, link_status: event.target.value })
                  }
                >
                  <option value="">All games</option>
                  {Object.entries(statuses).map(([value, text]) => (
                    <option key={value} value={value}>
                      {text}
                    </option>
                  ))}
                </select>
              </div>
            </div>
            <div {...stylex.props(styles.advancedActions)}>
              <button
                type="button"
                {...stylex.props(ui.nativeButton, ui.button, ui.primary)}
                onClick={() => apply(values)}
              >
                Apply filters
              </button>
            </div>
          </>
        )}
      </div>
      {!expanded && active.length > 0 && (
        <div
          {...stylex.props(styles.appliedFilters)}
          aria-label="Applied game filters"
          role="group"
        >
          {active.map(([key, label]) => {
            const value = applied[key];
            const display = Array.isArray(value)
              ? value.length > 1
                ? `${value[0]} +${value.length - 1}`
                : value[0]
              : key === "link_status"
                ? statuses[value as keyof typeof statuses]
                : value;
            return (
              <button
                type="button"
                key={key}
                {...stylex.props(ui.nativeButton, styles.filterToken)}
                aria-label={`Remove ${label.toLowerCase()} filter`}
                onClick={() =>
                  apply({
                    ...applied,
                    q: values.q,
                    [key]: emptyGameFilters[key],
                  })
                }
              >
                {label} · {display} <span aria-hidden="true">×</span>
              </button>
            );
          })}
        </div>
      )}
      {errors.length > 0 && (
        <ul {...stylex.props(ui.danger, ui.errorList)} role="alert">
          {errors.map((error) => (
            <li key={error}>{error}</li>
          ))}
        </ul>
      )}
    </fieldset>
  );
}
