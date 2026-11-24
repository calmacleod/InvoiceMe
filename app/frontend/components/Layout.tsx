import Link from "./AppLink";
import { layout } from "./Layout.stylex";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../styles/ui.stylex";
import { router, usePage } from "@inertiajs/react";
import { useState, type PropsWithChildren } from "react";
import DevStyleX from "./DevStyleX";

const destinations = [
  { id: "invoices", href: "/", label: "Invoices" },
  { id: "invoice_drafts", href: "/invoice_drafts", label: "Draft workbench" },
  { id: "invoice_groups", href: "/invoice_groups", label: "Invoice groups" },
  { id: "expenses", href: "/expenses", label: "Association expenses" },
  {
    id: "official_payments",
    href: "/official_payments",
    label: "Officials payments",
  },
  { id: "games", href: "/games", label: "Games & officials" },
  { id: "contacts", href: "/contacts", label: "Contacts" },
  { id: "seasons", href: "/seasons/new", label: "Year & settings" },
];

function Brand() {
  return (
    <Link {...stylex.props(ui.link, layout.brand)} href="/">
      <span {...stylex.props(layout.brandSymbol)} aria-hidden="true">
        i<span {...stylex.props(layout.brandM)}>m</span>
      </span>
      InvoiceMe
    </Link>
  );
}

export default function Layout({ children }: PropsWithChildren) {
  const {
    auth,
    seasons,
    current_season: season,
    flash = {},
    section,
  } = usePage().props;
  const [menuOpen, setMenuOpen] = useState(false);
  const [switchingYear, setSwitchingYear] = useState(false);
  const activeSection = section === "horizon_game_syncs" ? "games" : section;
  const yearUrl = season ? `/seasons/${season.id}/edit` : "/seasons/new";

  return (
    <div {...stylex.props(ui.app, !auth && layout.guest)}>
      <DevStyleX />
      {auth && (
        <>
          <a {...stylex.props(layout.skipLink)} href="#workspace">
            Skip to content
          </a>
          <aside {...stylex.props(layout.sidebar)}>
            <div {...stylex.props(layout.sidebarTop)}>
              <Brand />
              <button
                type="button"
                {...stylex.props(ui.nativeButton, layout.menuButton)}
                aria-expanded={menuOpen}
                aria-controls="workspace-navigation"
                onClick={() => setMenuOpen(!menuOpen)}
              >
                {menuOpen ? "Close menu" : "Menu"}
              </button>
            </div>
            <nav
              id="workspace-navigation"
              {...stylex.props(layout.nav, menuOpen && layout.navOpen)}
              aria-label="Main navigation"
            >
              {destinations.map(({ id, href, label }) => (
                <Link
                  key={id}
                  {...stylex.props(
                    ui.link,
                    layout.navLink,
                    activeSection === id && layout.navActive,
                  )}
                  href={id === "seasons" ? yearUrl : href}
                  aria-current={activeSection === id ? "page" : undefined}
                  onSuccess={() => setMenuOpen(false)}
                >
                  {label}
                </Link>
              ))}
            </nav>
          </aside>
        </>
      )}
      <main {...stylex.props(auth && layout.main)} id="workspace" tabIndex={-1}>
        {auth && (
          <header {...stylex.props(layout.topbar)}>
            <span {...stylex.props(layout.association)}>EOTFOA</span>
            <div {...stylex.props(layout.account)}>
              {season && (
                <label {...stylex.props(layout.year)}>
                  <span>Year</span>
                  <select
                    {...stylex.props(ui.input, layout.yearInput)}
                    id="active-year"
                    aria-label="Invoice year"
                    value={season.id}
                    disabled={switchingYear}
                    onChange={(event) =>
                      router.post(
                        "/select_year",
                        { id: event.target.value, section: activeSection },
                        {
                          preserveState: false,
                          onStart: () => setSwitchingYear(true),
                          onFinish: () => setSwitchingYear(false),
                        },
                      )
                    }
                  >
                    {seasons.map((item) => (
                      <option key={item.id} value={item.id}>
                        {item.year}
                      </option>
                    ))}
                  </select>
                </label>
              )}
              <span {...stylex.props(layout.email)}>{auth.email}</span>
              <Link
                {...stylex.props(ui.link, ui.textButton, layout.signOut)}
                href="/session"
                method="delete"
                as="button"
              >
                Sign out
              </Link>
            </div>
          </header>
        )}
        <div {...stylex.props(auth ? layout.content : layout.guestContent)}>
          {!auth && (
            <div {...stylex.props(layout.guestBrand)}>
              <Brand />
            </div>
          )}
          {Object.entries(flash).map(([type, message]) => (
            <div
              {...stylex.props(ui.flash, type === "alert" && ui.alert)}
              key={type}
              role={type === "alert" ? "alert" : "status"}
            >
              {message}
            </div>
          ))}
          {children}
        </div>
      </main>
    </div>
  );
}
