import React from "react";
import { createRoot } from "react-dom/client";
import { createInertiaApp } from "@inertiajs/react";
import Layout from "../components/Layout";

const pages = import.meta.glob("../pages/**/*.jsx", { eager: true });
createInertiaApp({
  nonce: document.querySelector('meta[name="csp-nonce"]')?.content,
  serverHead: true,
  title: (title) => (title ? `${title} · InvoiceMe` : "InvoiceMe · EOTFOA"),
  resolve: (name) => {
    const page = pages[`../pages/${name}.jsx`];
    if (!page) throw new Error(`Unknown page: ${name}`);
    page.default.layout = (page) => <Layout>{page}</Layout>;
    return page;
  },
  setup({ el, App, props }) {
    createRoot(el).render(
      <React.StrictMode>
        <App {...props} />
      </React.StrictMode>,
    );
  },
  defaults: { form: { withAllErrors: true } },
});
