import * as stylex from "@stylexjs/stylex";
import { colors, space } from "../../styles/tokens.stylex";

export const styles = stylex.create({
  categoryField: {
    display: "grid",
    gap: space.sm,
    minWidth: 0,
  },
  filters: {
    display: "grid",
    gridTemplateColumns: {
      default: "minmax(12rem, 2fr) minmax(8rem, 1fr) minmax(7rem, 1fr) auto",
      "@media (max-width: 1020px)": "repeat(2, minmax(0, 1fr))",
      "@media (max-width: 600px)": "minmax(0, 1fr)",
    },
    gap: space.md,
    alignItems: "end",
    padding: space.md,
    borderBottomWidth: 1,
    borderBottomStyle: "solid",
    borderBottomColor: colors.borderSoft,
  },
  item: {
    display: "grid",
    gridTemplateColumns: {
      default: "minmax(10rem, 2fr) minmax(9rem, 1fr) minmax(7rem, 1fr) auto",
      "@media (max-width: 1020px)": "repeat(2, minmax(0, 1fr))",
      "@media (max-width: 600px)": "minmax(0, 1fr)",
    },
    gap: space.md,
    alignItems: "end",
    paddingBottom: space.md,
    marginBottom: space.md,
    borderBottomWidth: 1,
    borderBottomStyle: "solid",
    borderBottomColor: colors.borderSoft,
  },
  controls: {
    display: "flex",
    alignItems: "center",
    flexWrap: "wrap",
    gap: space.md,
  },
  total: {
    display: "flex",
    gap: space.md,
    alignItems: "center",
    flexWrap: "wrap",
    marginTop: space.lg,
  },
  status: {
    marginTop: space.sm,
    marginBottom: 0,
  },
  labelSpace: { marginBottom: space.sm },
});
