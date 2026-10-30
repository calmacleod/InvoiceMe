import { useState } from "react";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../styles/ui.stylex";
import { colors, space } from "../styles/tokens.stylex";

export default function SearchableMultiSelect({
  id,
  label,
  options,
  value,
  onChange,
}: {
  id: string;
  label: string;
  options: string[];
  value: string | string[];
  onChange: (value: string[]) => void;
}) {
  const [query, setQuery] = useState("");
  const selected = Array.isArray(value) ? value : value ? [value] : [];
  const choices = [...new Set([...selected, ...options])].filter((option) =>
    option.toLocaleLowerCase().includes(query.toLocaleLowerCase()),
  );
  return (
    <div>
      <span {...stylex.props(ui.label)}>{label}</span>
      <details
        onKeyDown={(event) => {
          if (
            event.key === "Enter" &&
            event.target instanceof HTMLInputElement
          ) {
            event.preventDefault();
            event.stopPropagation();
          }
          if (event.key === "Escape") event.currentTarget.open = false;
        }}
      >
        <summary
          {...stylex.props(ui.input, styles.summary)}
          aria-label={`${label} options`}
        >
          {selected.length ? selected.join(", ") : `Any ${label.toLowerCase()}`}
        </summary>
        <div {...stylex.props(styles.panel)}>
          <input
            {...stylex.props(ui.input)}
            id={id}
            type="search"
            aria-label={`Search ${label.toLowerCase()}`}
            placeholder={`Search ${label.toLowerCase()}…`}
            value={query}
            onChange={(event) => setQuery(event.target.value)}
          />
          <div
            {...stylex.props(styles.options)}
            role="group"
            aria-label={label}
          >
            {choices.map((option) => (
              <label key={option} {...stylex.props(styles.option)}>
                <input
                  {...stylex.props(ui.checkbox)}
                  type="checkbox"
                  checked={selected.includes(option)}
                  onChange={(event) =>
                    onChange(
                      event.target.checked
                        ? [...selected, option]
                        : selected.filter((item) => item !== option),
                    )
                  }
                />
                {option}
              </label>
            ))}
            {!choices.length && <p {...stylex.props(ui.hint)}>No matches</p>}
          </div>
          <button
            type="button"
            {...stylex.props(ui.nativeButton, ui.textButton)}
            onClick={() => {
              onChange([]);
              setQuery("");
            }}
          >
            Clear selection
          </button>
        </div>
      </details>
    </div>
  );
}

const styles = stylex.create({
  summary: {
    cursor: "pointer",
    overflow: "hidden",
    textOverflow: "ellipsis",
    whiteSpace: "nowrap",
  },
  panel: {
    padding: space.sm,
    borderWidth: 1,
    borderStyle: "solid",
    borderColor: colors.border,
    borderRadius: 6,
    backgroundColor: colors.surface,
  },
  options: {
    maxHeight: 220,
    overflowY: "auto",
    paddingTop: space.sm,
    paddingBottom: space.sm,
  },
  option: {
    display: "flex",
    alignItems: "center",
    gap: space.sm,
    padding: space.sm,
    cursor: "pointer",
    fontSize: 12,
    overflowWrap: "anywhere",
  },
});
