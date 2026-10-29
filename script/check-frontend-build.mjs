import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

const output = resolve("public/assets/vite");
const manifest = JSON.parse(
  await readFile(resolve(output, ".vite/manifest.json"), "utf8"),
);
const entry = manifest["entrypoints/inertia.tsx"];
assert(
  entry?.isEntry,
  "The typed Inertia entrypoint must be in the Vite manifest",
);
assert(
  entry.css?.length,
  "Rails needs a stylesheet entry for the compiled StyleX styles",
);
const css = (
  await Promise.all(
    entry.css.map((file) => readFile(resolve(output, file), "utf8")),
  )
).join("\n");
assert.match(
  css,
  /@layer priority/,
  "StyleX atomic rules must be extracted into CSS",
);
assert.match(css, /@media/, "Responsive StyleX rules must be present");
assert.match(css, /--[\w-]+:/, "Shared design tokens must be emitted");
console.log("TypeScript entrypoint and extracted StyleX CSS verified.");
