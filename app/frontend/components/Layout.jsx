import { Link, router, usePage } from "@inertiajs/react";

export default function Layout({ children }) {
  const {
    auth,
    seasons,
    current_season: season,
    flash = {},
    section,
  } = usePage().props;
  return (
    <>
      <aside className="sidebar">
        <Link className="brand" href="/">
          <span className="brand-symbol">
            i<span>m</span>
          </span>
          <span>
            InvoiceMe<small>TREASURER WORKSPACE</small>
          </span>
        </Link>
        <div className="workspace">
          <span className="avatar">EO</span>
          <div>
            EOTFOA<small>Football officials’ association</small>
          </div>
        </div>
        {auth && (
          <>
            <p className="nav-caption">WORKSPACE</p>
            <nav aria-label="Main navigation">
              <Link href="/" className={section === "invoices" ? "active" : ""}>
                ▤ Invoices
              </Link>
              <Link
                href="/games"
                className={section === "games" ? "active" : ""}
              >
                ▦ Games & officials
              </Link>
              <Link
                href={season ? `/seasons/${season.id}/edit` : "/seasons/new"}
                className={section === "seasons" ? "active" : ""}
              >
                ⚙ Year & settings
              </Link>
            </nav>
            <div className="year-box">
              <span className="nav-caption">INVOICE YEAR</span>
              {seasons.map((s) => (
                <button
                  key={s.id}
                  className="year-button"
                  onClick={() => router.post(`/seasons/${s.id}/select`)}
                >
                  {s.year} {s.id === season?.id ? "✓" : ""}
                </button>
              ))}
              <Link href="/seasons/new" className="small-link">
                + Set up another year
              </Link>
            </div>
            <div className="sidebar-footer">
              <span className="avatar">CM</span>
              <div>
                <strong>Treasurer</strong>
                <small>{auth.email}</small>
              </div>
              <Link
                href="/session"
                method="delete"
                as="button"
                className="text-button"
              >
                Sign out
              </Link>
            </div>
          </>
        )}
      </aside>
      <main>
        <header className="topbar">
          <span>
            EOTFOA <span className="muted">/</span>{" "}
            {section?.replaceAll("_", " ")}
          </span>
          <span className="topbar-right">
            <span className="status-dot" />
            {auth && season ? (
              <div className="year-select">
                <label htmlFor="active-year">Invoice year</label>
                <select
                  id="active-year"
                  value={season.id}
                  onChange={(event) =>
                    router.post("/select_year", { id: event.target.value })
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
            <span className="avatar small">CM</span>
          </span>
        </header>
        <div className="content">
          {Object.entries(flash).map(([type, message]) => (
            <div key={type} role="status" className={`flash ${type}`}>
              {message}
            </div>
          ))}
          {children}
          <footer className="page-footer">
            Made for a little less paperwork. <span>InvoiceMe · EOTFOA</span>
          </footer>
        </div>
      </main>
    </>
  );
}
