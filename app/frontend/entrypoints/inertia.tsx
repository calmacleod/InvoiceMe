import type { PageModule } from "../types";
import React from "react";
import { createRoot } from "react-dom/client";
import { createInertiaApp } from "@inertiajs/react";
import Layout from "../components/Layout";
import "../styles/reset.css";

const pages = import.meta.glob<PageModule>("../pages/**/*.tsx", {
  eager: true,
});
createInertiaApp({
  nonce: document.querySelector<HTMLMetaElement>('meta[name="csp-nonce"]')
    ?.content,
  serverHead: true,
  title: (title) => (title ? `${title} · InvoiceMe` : "InvoiceMe · EOTFOA"),
  resolve: (name) => {
    const page = pages[`../pages/${name}.tsx`];
    if (!page) throw new Error(`Unknown page: ${name}`);
    page.default.layout = (page) => <Layout>{page}</Layout>;
    return page;
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
