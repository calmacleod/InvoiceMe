import type { PageModule } from "../types";
import React from "react";
import { createRoot } from "react-dom/client";
import { createInertiaApp, router } from "@inertiajs/react";
import Layout from "../components/Layout";
import "../styles/reset.css";

const pages = import.meta.glob<PageModule>("../pages/**/*.tsx");
// Cached responses are scoped to the current workspace state. Clear them before
// mutations, including year changes and sign-out, so hover never restores stale data.
router.on("before", (event) => {
  if (event.detail.visit.method !== "get") router.flushAll();
});
createInertiaApp({
  nonce: document.querySelector<HTMLMetaElement>('meta[name="csp-nonce"]')
    ?.content,
  serverHead: true,
  title: (title) => (title ? `${title} · InvoiceMe` : "InvoiceMe · EOTFOA"),
  resolve: async (name) => {
    const load = pages[`../pages/${name}.tsx`];
    if (!load) throw new Error(`Unknown page: ${name}`);
    const page = await load();
    page.default.layout = (page) => <Layout>{page}</Layout>;
    return page.default;
  },
  setup({ el, App, props }) {
    if (!el) throw new Error("Missing Inertia root element");
    createRoot(el).render(
      <React.StrictMode>
        <App {...props} />
      </React.StrictMode>,
    );
  },
  defaults: { form: { withAllErrors: true } },
});
