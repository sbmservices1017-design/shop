# ShopDesk Pro v0.7.0 — NexaDash-inspired UI update

## What changed

- New shared palette / auth layout in `lib/nexa_theme.dart`: dark navy background, electric-blue primary controls, soft gradient panels, subtle borders and modern round corners.
- Main dashboard rebuilt in `lib/advanced_dashboard.dart` to closely follow the uploaded dashboard reference: four summary cards, sales/purchases line chart, sales-by-category donut, Recent Orders, Top Selling Products, expenses and stock/receivables.
- Dashboard metrics are queried from **local SQLite** (every 5 seconds) and filtered by 7/14/30 days. Data is not seeded with illustrative figures.
- Matching dark Login / Owner Registration, First Launch (create DB or restore), and License Activation screens use `NexaAuthLayout`.
- Left navigation, search by assigned module, header, and license timer updated. Countdown is updated each second using the existing component.
- Settings menu also uses the same dark palette. Existing settings ordering remains Shop Profile, Users & Permissions, Backup & Restore, License Activation, System Information.

## What was deliberately *not* changed

`lib/store.dart`, `lib/extensions.dart`, `lib/reporting.dart`, `lib/modern_pos.dart`, `lib/commercial_core.dart`, and `lib/license_public.dart` are unchanged compared with v0.6.1. The app's stock, invoices, customer/supplier ledgers, payroll, POS, signed offline activation, and database migration still use the original implementations.

## Important boundaries

- The provided image is a **visual reference**, not a promise of pixel-by-pixel duplication. Flutter rendering and responsive window sizes differ from the screenshot.
- Dashboard data refreshes by periodic SQLite polling every 5 seconds rather than subscribing to a database change stream.
- Profit/COGS is not displayed because confirmed stock-costing is not implemented in the base system.
- The source was not compiled in this environment; only code-balance/static file checks and SQLite-query execution with fixture data were performed.

## Build on a separate GitHub branch

1. Back up the working shop database and the working Windows release.
2. Create a new GitHub branch such as `nexadash-ui-v0.7`.
3. Upload **contents inside `ShopDesk/`** at the repository root; ensure `.github/workflows/windows-build.yml` is present.
4. Run GitHub Actions workflow **Build ShopDesk Windows EXE (v0.7.0)**.
5. Confirm `Static analyzer`, `ShopDesk database and commercial regression tests`, and `Build Windows release` are green.
6. Run the release **on a test database first**, verifying registration, login, license timer, settings, sales/purchase entry, ledger balances, returns and A4 reports.
7. If it fails, open the red step and share the first Dart error plus approximately 15 lines after it.

**Never upload private license generator signing keys or your live shop database to a public repository.**
