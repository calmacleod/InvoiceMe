import react from "@vitejs/plugin-react";
import inertia from "@inertiajs/vite";
import { defineConfig } from "vite";
import RubyPlugin from "vite-plugin-ruby";
import stylex from "@stylexjs/unplugin";

export default defineConfig({
  plugins: [
    RubyPlugin(),
    inertia(),
    stylex.vite({
      useCSSLayers: true,
      runtimeInjection: false,
      devMode: "css-only",
    }),
    react(),
  ],
});
