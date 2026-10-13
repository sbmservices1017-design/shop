# ShopDesk Pro v0.8.0 — all-in-one update

This version is based on the supplied v0.7 Flutter SOURCE. It is a development source release, **not a compiled or production-verified EXE**.

## Included changes

1. White + light-blue styling shared by dashboard, sidebar, first launch, owner registration, login, settings and activation. Increased contrast and text visibility, prominent Windows scrollbar theming.
2. Live dashboard with date-range picker. Selected from/to dates apply to sales, purchases, expenses, recent invoices, top sellers and sales by category; Clear Filter returns to a live rolling 30-day view. SQLite data refreshes every 5 seconds. Snapshot customer/stock balances still represent the latest balances, not historical as-of-date inventory.
3. Sidebar begins Dashboard, POS, Sales Invoices, Sale Returns, Purchase Invoices, Purchase Returns. Other inventory, supplier, customer, payroll, accounts, reports and settings modules are retained.
4. POS page opens directly into POS interface, with sale/purchase mode selector. Invoice history toggle is removed from POS.
5. Sales/Purchase Invoices pages show only invoices and their actions, searchable by invoice number and customer/supplier, filtered by Paid / Unpaid / Partially Paid.
6. Sales Returns and Purchase Returns have separately filtered pages and independent source invoice selectors.
7. Clicking Trial Expires In / license status opens a license activation dialog with Machine ID, key input and signature-based validation via existing CommercialCore.
8. Edit invoice updates **the same document ID and invoice number**, preserving old stock and ledger postings through reversals and an immutable old-invoice snapshot in `document_revisions`. Edit is blocked for linked receipts and returns to protect financial/stock consistency. Errors rollback atomically. Voiding a revised invoice reverses only the active revision postings.
9. Settings > Invoice Serial Numbers: independent Sale/Purchase prefix and next sequence counter. Atomic SQLite counters skip collisions and do not rename previously issued invoices.

## Regression scenarios for Windows/GitHub

- Backup a COPY of the live SQLite database before starting; never overwrite a live installation.
- Run Flutter analyzer and all tests in GitHub Actions. Confirm build artifact has exe+DLLs+data directory.
- Verify no `flutter analyze` errors. Inspect widget layout at 1366x768 and 1920x1080; ensure all scrollbars visibly work with mouse and wheel.
- Create sale and purchase, confirm `SAL-000001` and `PUR-000001` (or configured prefixes). Set next numbers in Settings, create more, confirm collisions skipped.
- Edit sale twice and compare the unchanged invoice ID/number, its item quantities, stock and customer ledger with old revisions. Void and verify stock/ledger balances.
- Edit purchase invoice similarly and verify supplier ledger, stock and journal remain balanced.
- Test invoice edits with allocated receipts and returns; they should be blocked with a meaningful error, not corrupt data.
- Sales Invoices and Purchase Invoices: search with invoice number and party name and filter each payment status. Ensure filters clear and views only show their correct invoice kinds.
- Test both Sale Returns and Purchase Returns pages with partial quantities and reversal.
- Choose a dashboard date range with past/zero-data dates. Check sales, purchases, expenses, recent orders, top products, category graph; clear filter returns rolling live data. Note live outstanding/stock panels show current position regardless of selected date.
- Verify trial-status click opens activation, wrong key rejected and valid signed key activates. Keep PRIVATE signing key entirely outside source/repository/build artifacts.
- Ensure a cashier without Purchases permissions cannot create purchases through POS. Recheck module permissions after sidebar changes.

## Verification performed in packaging environment

- Dart-source balanced delimiter scan of all `lib/*.dart` files.
- Extracted SQLite DDL smoke test (26 tables) with FK enforcement and sample dataset checks for date filters, paid invoice and stock movements.
- Project archive integrity test.

## Not verified here

- **Flutter analyzer, Windows compilation, visual screenshot matching and complete user acceptance testing**, as Flutter/Dart SDK is absent from this environment.
- Full production accounting and COGS/inventory valuation correctness remain outside current certification. Do not use a live shop database until verified on a copy and backed up.
