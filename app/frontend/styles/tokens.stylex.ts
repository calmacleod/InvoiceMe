import * as stylex from "@stylexjs/stylex";

export const colors = stylex.defineVars({
  canvas: "#f6f7f3",
  surface: "#ffffff",
  text: "#203a34",
  secondary: "#65745e",
  muted: "#78847c",
  subtle: "#9aa38f",
  accent: "#285e46",
  accentHover: "#204b38",
  accentSoft: "#eaf0e6",
  border: "#dce3d7",
  borderSoft: "#eff1eb",
  focus: "#8aaa71",
  notice: "#eef4e7",
  danger: "#9c5f42",
  dangerSurface: "#fdf0e9",
  dangerBorder: "#ebd0c0",
  amber: "#a0803e",
});

export const space = stylex.defineVars({
  xs: "4px",
  sm: "8px",
  md: "12px",
  lg: "16px",
  xl: "24px",
  xxl: "32px",
});

export const shape = stylex.defineVars({
  control: "6px",
  card: "9px",
  font: "Arial, Helvetica, sans-serif",
});
