# ShopDesk Pro v0.9.15 — Stock Ledger, Price Edit, Expense Delete, Variation UX

Latest source changes and safe SQLite migrations: see [UPGRADE_V0_9_15_STOCK_EXPENSE_VARIATIONS.md](UPGRADE_V0_9_15_STOCK_EXPENSE_VARIATIONS.md). Flutter/Windows compilation is not verified in this environment. Test on a backup database before production use.

# ShopDesk Pro v0.9.14 — POS-Style Sale/Purchase Returns

See [UPGRADE_V0_9_14_RETURN_POS_AND_INVOICE_QTY.md](UPGRADE_V0_9_14_RETURN_POS_AND_INVOICE_QTY.md). This update adds full-invoice and selected-item returns, invoice-line variation and unit visibility, and original/returned/remaining quantities on invoices and reports. Flutter/Windows build **not yet verified**; use GitHub Actions.

**Latest UI update:** See [UPGRADE_V0_9_9.md](UPGRADE_V0_9_9.md) for full-screen POS and safe Delete controls.

# ShopDesk Pro v0.9.6 — Consolidated Client Changes

Windows Flutter + SQLite single-PC desktop project. Built on v0.9.5; old modules, data and SBM branding remain in source.

## Changes

- Stock Adjustment: Product → specific Size/Color/Pack variation; stock in canonical Feet/Pieces with signed adjustments, reason required.
- POS: the existing Roll packing variation supports sale in **Roll, Gazz, Feet**; ready-made Table Sheet Roll supports whole Roll or individual Table Sheets.
- Payroll: YYYY-MM salary period PLUS independent `YYYY-MM-DD` payment date. Date is saved in payroll, employee ledger, and journal.
- Sales AND Purchase POS: split payment into multiple Cash/Bank/Wallet rows on the same bill, with independent account ledger lines; remaining amount becomes receivable/payable.
- Sales AND Purchase invoice list: **Add Installment** payment with a selected payment account and payment date; installments target that exact invoice, not the oldest open bill.
- No auto-print popup. Manual A4 print remains on the invoice list.

## Safe accounting behavior

All invoice lines, split payments, stock movements, party ledger, and journal lines post **in one SQLite transaction**. Overpayment or invalid account rolls back all operations. Existing single-tender API remains compatible.

**Limitation requiring follow-up:** An invoice created with multiple payment methods cannot currently be corrected using the legacy single-account invoice editor: the editor rejects the edit instead of incorrectly redistributing tender balances. Reverse any later receipts before voiding an invoice. A dedicated multi-tender correction UI needs Windows acceptance testing and implementation before release.

## Validation status

- Flutter/Dart SDK is not available in this execution environment: `flutter analyze`, `flutter test` and Windows `.exe` compilation have **not** been run here.
- GitHub Actions workflow includes new regression test `test/v0_9_6_shop_changes_test.dart`.
- Keep the owner PRIVATE key outside GitHub. Always back up the customer `.sqlite` database before upgrading; test with demo data first.

## Build

Upload the **contents** of `ShopDesk/` to the repository root (including hidden `.github/`). In GitHub Actions run `Build ShopDesk Windows EXE (v0.9.6)`. Download the whole Windows release ZIP, not EXE alone. The app needs associated Flutter DLL/data files.



## v0.9.7 analyzer correction
See `FIX_NOTES_V0_9_7.md`. This update repairs one POS split-payment widget syntax error and supplies missing test variation parameters. No inventory, accounting, payroll, or licensing business methods were modified.


## v0.9.8 payroll UI regression correction
See `FIX_NOTES_V0_9_8.md`. Updates the stale payroll widget test to target stable keyed fields after the salary-date field addition; payroll calculations and database transactions are unchanged. Build with the v0.9.8 workflow.

## v0.9.10 — Ledger Payment Method, Compact POS, Customer Credit Card

- All customer and supplier ledger rows now include Payment Method. Multiple Cash/Bank/Wallet portions are stored as separate account-linked ledger entries. Installments and reversal rows retain their original payment account reference.
- Employee, Cash & Bank, and General Account Ledger reports expose a payment-method column; non-cash entries are explicitly identified as such. PDF/Excel exports inherit these headers.
- POS full-screen billing cart now uses dense invoice-table rows for Product/Variation, Unit, Quantity, Rate and Amount, with new items at the top. Payment details may be opened only when required; excess line items still have a scrollbar.
- Dashboard includes a live **Customer Credit Due** card, scoped to the selected date range; clear date filter restores rolling 30-day view.
- SQLite migration retains old data and adds an optional `payment_account_id` field to party_ledger. Existing 0.9.x invoices are not rewritten.
- Build/test checks now include `test/ledger_payment_credit_test.dart`; Windows SDK build still pending. See `UPGRADE_V0_9_10.md` for details.


## v0.9.12 — Keyboard shortcuts

Press **F1** (or the keyboard icon in the top bar) to see all available
shortcuts. F2 opens full-screen POS; F3 opens Sales Invoices; F4 opens
Purchase Invoices; F5 refreshes; Ctrl+K searches modules. In the POS,
Ctrl+F focuses product search, Enter chooses the first match, Ctrl+S
saves through existing permission/validation checks and F6 toggles
payment details. Leaving a POS with unsaved cart items asks for confirmation.
See `KEYBOARD_SHORTCUTS_V0_9_12.md` for the complete map.


## v0.9.13 — Invoice Payment Correction & Regression Fix

See `FIX_NOTES_V0_9_13.md`. Single-tender invoice payment corrections are audited; multiple tenders and allocated installments are preserved while items/rates can be revised with unchanged recorded payment total.
