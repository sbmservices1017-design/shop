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

