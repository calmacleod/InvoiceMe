import { Combobox } from "@base-ui/react/combobox";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../styles/ui.stylex";
import { colors, shape, space } from "../styles/tokens.stylex";

export default function SearchableMultiSelect({
  id,
  label,
  options,
  value: selection,
  disabled,
  onChange,
}: {
  id: string;
  label: string;
  options: string[];
  value: string | string[];
  disabled: boolean;
  onChange: (value: string[]) => void;
}) {
  const value = Array.isArray(selection)
    ? selection
    : selection
      ? [selection]
      : [];
  const items = [...new Set([...value, ...options])];
  return (
    <div>
      <Combobox.Root
        multiple
        items={items}
        value={value}
        disabled={disabled}
        onValueChange={onChange}
        onInputValueChange={(_, event) => {
          if (event.isItemPress) event.cancel();
        }}
      >
        <Combobox.Label {...stylex.props(ui.label)}>{label}</Combobox.Label>
        <Combobox.Trigger id={id} {...stylex.props(ui.input, styles.trigger)}>
          <span {...stylex.props(styles.value)}>
            {value.length === 0
              ? "Any"
              : value.length === 1
                ? value[0]
                : `${value.length} selected`}
          </span>
          <Combobox.Icon aria-hidden="true">▾</Combobox.Icon>
        </Combobox.Trigger>
        <Combobox.Portal>
          <Combobox.Positioner
            {...stylex.props(styles.positioner)}
            align="start"
            sideOffset={5}
            collisionPadding={12}
          >
            <Combobox.Popup
              {...stylex.props(styles.popup)}
              onKeyDown={(event) => {
                if (event.key === "Enter") event.stopPropagation();
              }}
            >
              <Combobox.Input
                {...stylex.props(ui.input)}
                aria-label={`Search ${label.toLowerCase()}`}
                placeholder={`Search ${label.toLowerCase()}`}
              />
              <Combobox.Empty {...stylex.props(styles.empty)}>
                No matches
              </Combobox.Empty>
              <Combobox.List {...stylex.props(styles.list)}>
                {(item: string) => (
                  <Combobox.Item
                    key={item}
                    value={item}
                    className={({ highlighted }) =>
                      stylex.props(
                        styles.item,
                        highlighted && styles.highlighted,
                      ).className
                    }
                  >
                    <span {...stylex.props(styles.check)}>
                      <Combobox.ItemIndicator aria-hidden="true">
                        ✓
                      </Combobox.ItemIndicator>
                    </span>
                    {item}
                  </Combobox.Item>
                )}
              </Combobox.List>
              {value.length > 0 && (
                <button
                  type="button"
                  {...stylex.props(ui.nativeButton, ui.button, styles.clear)}
                  onClick={() => onChange([])}
                >
                  Clear selection
                </button>
              )}
            </Combobox.Popup>
          </Combobox.Positioner>
        </Combobox.Portal>
      </Combobox.Root>
    </div>
  );
}

const styles = stylex.create({
  trigger: {
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    gap: space.sm,
    textAlign: "left",
    cursor: "pointer",
  },
  value: {
    minWidth: 0,
    overflow: "hidden",
    textOverflow: "ellipsis",
    whiteSpace: "nowrap",
  },
  positioner: { zIndex: 25 },
  popup: {
    display: "flex",
    flexDirection: "column",
    gap: space.xs,
    padding: space.sm,
    width: "min(max(230px, var(--anchor-width)), var(--available-width))",
    maxHeight: "min(325px, var(--available-height))",
    borderWidth: 1,
    borderStyle: "solid",
    borderColor: colors.border,
    borderRadius: shape.card,
    backgroundColor: colors.surface,
    color: colors.text,
    fontFamily: shape.font,
    fontSize: 13,
    boxShadow: "0 6px 24px #17251a26",
  },
  list: { overflowY: "auto", overscrollBehavior: "contain", minHeight: 0 },
  item: {
    display: "grid",
    gridTemplateColumns: "16px minmax(0, 1fr)",
    alignItems: "center",
    gap: space.xs,
    minHeight: 36,
    padding: "6px 8px",
    borderRadius: shape.control,
    overflowWrap: "anywhere",
    cursor: "default",
  },
  check: { color: colors.accent, fontWeight: 700 },
  highlighted: { backgroundColor: colors.accentSoft },
  empty: { color: colors.muted, padding: "3px 8px" },
  clear: { alignSelf: "start" },
});
