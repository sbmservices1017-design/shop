## v0.4.3 GitHub build guard patch

If the workflow fails at **Verify corrected ShopDesk sources were uploaded** with `reviseDocument closing fix missing`, replace `.github/workflows/windows-build.yml` from this package. That error can result from Windows line-ending conversion, not a missing Dart fix. See `GITHUB_GUARD_FIX.md`. **Flutter compile still needs verification on GitHub.**

# ShopDesk Flutter v0.4.2 — Analyzer Fix

> **Development source, NOT a verified Windows EXE.** Check `FIX_NOTES.md` for the essential replacement steps.

# ShopDesk v0.4.0 — Integrated Flutter Desktop Source

**Target:** one Windows 10/11 shop computer · Flutter · offline SQLite · PKR.

This delivery contains **one consolidated application source tree** and a complete requirements specification. **It is NOT a compiled or certified production Windows EXE.** Do not begin live shop accounting until the complete Windows acceptance checklist passes.

## Latest integrated implementation

- Consistent light-content/dark-sidebar Material 3 desktop layout.
- Product categories and category-specific dynamic attributes (text, number, choice), independent SKU variants, stock adjustments and negative stock.
- Sales/bills with manually entered prices; purchases with supplier and payments, customer and supplier receivables/payables.
- Post/void sales or purchase invoices; **correct a posted invoice through one SQLite transaction** that reverses the old document and posts a new one, preserving audit history. Refuses corrections if linked posted returns exist.
- Sales returns, purchase returns, original-line quantity guardrails and payment/expense reversals.
- Customer and supplier profiles, opening balances, payments, **running-balance ledgers with PDF/Excel/A4 print**.
- Expense categories (add/rename), expense entries, reversal and general ledger postings.
- Employees, advances, salary recovery, monthly payroll, deferred salary payment and printable employee ledger.
- Chart of accounts, cash/bank transfer, manual journal and trial-balance reporting.
- **27 report definitions** with date, party, product, category, SKU, employee, expense category, stock status, payment status, amount-range and search filters where appropriate, as well as PDF, .xlsx and A4 printing.
- SQLite backup via `VACUUM INTO`, consistency diagnostics, stock and journal audit history.

## Project layout

- `lib/main.dart` — Windows desktop interface / forms / module navigation.
- `lib/store.dart` — SQLite schema, inventory, invoices, journals and payroll.
- `lib/extensions.dart` — returns/refunds, opening balances, reversals, consistency verification.
- `lib/reporting.dart` — reporting and PDF / Excel / A4 printing.
- `docs/FULL_REQUIREMENTS.md` — **complete user-requested functional specification and acceptance criteria**.
- `docs/MODULE_MATRIX.md` — existing implementation and release gaps.
- `test/store_test.dart` — Dart regression tests to execute in the Flutter environment.
- `build_windows.bat` and `.github/workflows/windows-build.yml` — Windows build and CI recipe.

## Run from a Windows desktop

1. Install a current stable **Flutter SDK** and **Visual Studio 2022 Community** with the **Desktop development with C++** workload. Add Flutter to PATH.
2. Extract the whole ZIP to a normal folder, e.g. `C:\ShopDesk_Source`.
3. Open a terminal there and run:

```powershell
flutter doctor -v
flutter create --platforms=windows .
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter run -d windows
```

4. For release: double-click `build_windows.bat` or run `flutter build windows --release`.
5. The installed Flutter **Windows app is a Release folder**, typically `build\windows\x64\runner\Release`. Keep EXE together with DLL/runtime/data files; do not copy the EXE alone. This project does not currently include a standalone `.msi` installer.
6. Alternatively, upload source to a GitHub repository and run the included **Build ShopDesk Windows Bundle** workflow; it should create a ZIP artifact *if* Windows tests/build pass.

## Sample shop workflow

1. Category: Mattress; fields: Thickness, Size, Material. Add product and SKU `MAT-6IN-DOUBLE`.
2. Open sales, select SKU and quantity 5, set selling rate manually, then save. Stock 0 becomes **-5**.
3. Open purchases, choose supplier, buy 12 of the same SKU. Stock becomes **7**.
4. Receive partial payment from customer and pay supplier separately; review ledgers.
5. Add an expense, employee advance and monthly salary recovery.
6. Generate filtered Sales, Purchases, Stock, Customer Ledger, Supplier Ledger or Payroll report, then export PDF/Excel and print A4.

## Business-critical implementation notes

- Negative stock is **deliberately enabled**; zero available quantity does not stop valid invoices.
- Monetary values in the database use integer paisa; quantities are decimal up to three places in invoice/adjustment validation.
- Invoice corrections keep the original invoice as VOID plus a replacement invoice, rather than overwriting history.
- Inventory cost valuation **is not yet fully implemented**; the `Revenue & Expenses` view is **not** a valid final Profit & Loss statement. Do not use it to decide financial profit.
- Unit conversions (e.g., purchase a full roll and sell by meter), freight allocations, real aging schedules, complete payroll cancellation/correction, production sign-in/permissions, encrypted automatic backups and safe in-app restore remain development / verification work.
- Invoice corrections that affect past periods need an accounting period-close policy before production use.
- SQLite is local to one PC; do not open its live file from multiple computers across a shared network.

## Testing status (transparent)

- **Checked here:** ZIP/file consistency, SQLite CREATE schema in a fresh SQLite instance, foreign key layout, database integrity, and the negative-stock arithmetic example.
- **Added but NOT executed here:** Flutter automated regression cases for posting, returns, reversals, atomic bill correction, filtered reports, payroll and running-balance ledgers.
- **NOT checked here:** Flutter compilation or analyzer, Windows startup, actual PDF/Excel printer behavior, Windows release build/installer, realistic data migration, inventory costing/COGS, production backup/restore and accounting acceptance.

For the full feature-by-feature target, read `docs/FULL_REQUIREMENTS.md`. This specification includes requirements that have NOT yet been implemented; it is intentionally more comprehensive than the current development source.
