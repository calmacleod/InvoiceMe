# InvoiceMe

Use Rails 8.1 conventions: the generated Authentication concern, User/Session models, bcrypt, Action Mailer password resets, and normal bin/setup / bin/dev development on port 3000. Do not add a shared password gate, development authentication bypass, or custom environment-dependent login.

Deploy through bin/kamal and config/deploy.yml. Preserve the existing invoice_me_storage volume. Do not reintroduce Compose deployment or manually change the shared proxy's routes.

Horizon exports contain private customer and official information. Never commit an actual export, its rows, or real people from it. Fixtures must retain only the format and use fictional names, teams, locations, game IDs, dates, and monetary values. Keep local exports outside Git; the normal Horizon export filename pattern is ignored.

Use React with strict TypeScript, StyleX, and Inertia Rails with Vite for application screens and forms. Keep Rails authentication, controllers, validations, and invoice document generation on the server. Do not reintroduce Turbo, Stimulus, or Importmap for application navigation.

Use StyleX tokens and stylex.props for application UI. Retain the scoped invoice CSS for the shared React/document appearance; only minimal reset CSS belongs outside StyleX. Keep StyleX extraction in the Vite build, without runtime style injection.

Run bin/ci for Rails' standard checks. Use synthetic fixtures for automated tests and do not import supplied production data into the live app merely to test parsing.
