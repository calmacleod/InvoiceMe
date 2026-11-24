import * as stylex from "@stylexjs/stylex";

export const colors = stylex.defineVars({
  canvas: "#f5f4ef",
  surface: "#fffefa",
  text: "#202921",
  secondary: "#3e4b41",
  muted: "#57665a",
  subtle: "#657366",
  accent: "#285740",
  accentHover: "#1c4330",
  accentSoft: "#e8efe5",
  border: "#d8ded4",
  borderSoft: "#e8ebe4",
  focus: "#4d795e",
  notice: "#eaf2e7",
  danger: "#9a3e31",
  dangerSurface: "#fff1ec",
  dangerBorder: "#ecd0c7",
  amber: "#795720",
  sidebar: "#23382e",
  sidebarText: "#fcfbf4",
  sidebarMuted: "#d2dfd3",
  sidebarActive: "#385447",
  brand: "#edc991",
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
  font: "system-ui, -apple-system, BlinkMacSystemFont, sans-serif",
});
