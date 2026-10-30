import Link from "./AppLink";
import { layout } from "./Layout.stylex";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../styles/ui.stylex";
import { router, usePage } from "@inertiajs/react";
import type { PropsWithChildren } from "react";
import DevStyleX from "./DevStyleX";

export default function Layout({ children }: PropsWithChildren) {
  const {
    auth,
    seasons,
    current_season: season,
    flash = {},
    section,
  } = usePage().props;
  return (
    <div {...stylex.props(ui.app)}>
      <DevStyleX />
      <aside {...stylex.props(layout.sidebar)}>
        <Link
          navigateOnMouseDown
          {...stylex.props(ui.link, layout.brand)}
          href="/"
        >
          <span {...stylex.props(layout.brandSymbol)}>
            i<span {...stylex.props(layout.brandM)}>m</span>
          </span>
          <span>
            InvoiceMe
            <small {...stylex.props(ui.small, layout.brandCaption)}>
              TREASURER WORKSPACE
            </small>
          </span>
        </Link>
        <div {...stylex.props(layout.workspace)}>
          <span {...stylex.props(layout.avatar)}>EO</span>
          <div>
            EOTFOA
            <small {...stylex.props(ui.small, layout.workspaceCaption)}>
              Football officials’ association
            </small>
          </div>
        </div>
        {auth && (
          <>
            <p {...stylex.props(ui.paragraph, layout.navCaption)}>WORKSPACE</p>
            <nav {...stylex.props(layout.nav)} aria-label="Main navigation">
              <Link
                navigateOnMouseDown
                {...stylex.props(
                  ui.link,
                  layout.navLink,
                  section === "invoices" && layout.navActive,
                )}
                href="/"
              >
                ▤ Invoices
              </Link>
              <Link
                navigateOnMouseDown
                {...stylex.props(
                  ui.link,
                  layout.navLink,
                  section === "invoice_drafts" && layout.navActive,
                )}
                href="/invoice_drafts"
              >
                ◫ Draft workbench
              </Link>
              <Link
                navigateOnMouseDown
                {...stylex.props(
                  ui.link,
                  layout.navLink,
                  section === "games" && layout.navActive,
                )}
                href="/games"
              >
                ▦ Games & officials
              </Link>
              <Link
                navigateOnMouseDown
                {...stylex.props(
                  ui.link,
                  layout.navLink,
                  section === "contacts" && layout.navActive,
                )}
                href="/contacts"
              >
                ◉ Contacts
              </Link>
              <Link
                navigateOnMouseDown
                {...stylex.props(
                  ui.link,
                  layout.navLink,
                  section === "seasons" && layout.navActive,
                )}
                href={season ? `/seasons/${season.id}/edit` : "/seasons/new"}
              >
                ⚙ Year & settings
              </Link>
            </nav>
            <div {...stylex.props(layout.yearBox)}>
              <span {...stylex.props(layout.navCaption)}>INVOICE YEAR</span>
              {seasons.map((s) => (
                <button
                  {...stylex.props(ui.nativeButton, layout.yearButton)}
                  key={s.id}
                  onClick={() => router.post(`/seasons/${s.id}/select`)}
                >
                  {s.year} {s.id === season?.id ? "✓" : ""}
                </button>
              ))}
              <Link
                navigateOnMouseDown
                {...stylex.props(ui.link, ui.smallLink, layout.yearLink)}
                href="/seasons/new"
              >
                + Set up another year
              </Link>
            </div>
            <div {...stylex.props(layout.sidebarFooter)}>
              <span {...stylex.props(layout.avatar)}>CM</span>
              <div {...stylex.props(layout.footerIdentity)}>
                <strong {...stylex.props(ui.strong)}>Treasurer</strong>
                <small {...stylex.props(ui.small, layout.footerEmail)}>
                  {auth.email}
                </small>
              </div>
              <Link
                {...stylex.props(ui.link, ui.textButton)}
                href="/session"
                navigateOnMouseDown={false}
                method="delete"
                as="button"
              >
                Sign out
              </Link>
            </div>
          </>
        )}
      </aside>
      <main {...stylex.props(layout.main)}>
        <header {...stylex.props(layout.topbar)}>
          <span>
            EOTFOA <span {...stylex.props(ui.muted, layout.separator)}>/</span>{" "}
            {section?.replaceAll("_", " ")}
          </span>
          <span {...stylex.props(layout.topbarRight)}>
            <span {...stylex.props(layout.statusDot)} />
            {auth && season ? (
              <div {...stylex.props(layout.yearSelect)}>
                <label
                  {...stylex.props(ui.label, layout.srOnly)}
                  htmlFor="active-year"
                >
                  Invoice year
                </label>
                <select
                  {...stylex.props(ui.input, layout.yearSelectInput)}
                  id="active-year"
                  value={season.id}
                  onChange={(event) =>
                    router.post("/select_year", {
                      id: event.target.value,
                    })
                  }
                >
                  {seasons.map((s) => (
                    <option key={s.id} value={s.id}>
                      {s.year}
                    </option>
                  ))}
                </select>
              </div>
            ) : (
              "Treasurer workspace"
            )}
            <span {...stylex.props(layout.avatar, layout.smallAvatar)}>CM</span>
          </span>
        </header>
        <div {...stylex.props(layout.content)}>
          {Object.entries(flash).map(([type, message]) => (
            <div
              {...stylex.props(ui.flash, type === "alert" && ui.alert)}
              key={type}
              role="status"
            >
              {message}
            </div>
          ))}
          {children}
          <footer {...stylex.props(layout.pageFooter)}>
            Made for a little less paperwork. <span>InvoiceMe · EOTFOA</span>
          </footer>
        </div>
      </main>
    </div>
  );
}
