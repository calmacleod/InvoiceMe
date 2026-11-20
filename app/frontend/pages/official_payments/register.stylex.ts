import * as stylex from "@stylexjs/stylex";
import { colors } from "../../styles/tokens.stylex";

export const register = stylex.create({
  table: { borderCollapse: "separate", borderSpacing: 0 },
  scroll: { maxHeight: "65vh" },
  header: {
    position: "sticky",
    top: 0,
    zIndex: 1,
    padding: "9px 10px",
    verticalAlign: "bottom",
  },
  official: {
    position: "sticky",
    left: 0,
    zIndex: 1,
    minWidth: 165,
    backgroundColor: colors.surface,
  },
  officialHeader: { zIndex: 2 },
  row: { padding: "7px 10px", fontWeight: 400 },
  cell: {
    padding: 0,
    borderRightWidth: 1,
    borderRightStyle: "solid",
    borderRightColor: colors.border,
  },
  amount: { minWidth: 84 },
  name: { minWidth: 190 },
  description: { minWidth: 200 },
  control: {
    backgroundColor: { default: "transparent", ":disabled": colors.canvas },
    borderWidth: 0,
    borderRadius: 0,
    padding: "8px 9px",
    fontSize: 13,
    minHeight: 39,
    outlineOffset: -2,
    outlineColor: colors.focus,
  },
  numeric: { textAlign: "right", fontVariantNumeric: "tabular-nums" },
  pending: { backgroundColor: "#eff6ea" },
});
