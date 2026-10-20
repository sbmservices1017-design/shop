# ShopDesk Pro v0.9.14 — Return POS and Invoice Quantity Reconciliation

## Requested behaviour (Sale and Purchase)

1. **Original invoice stays auditable**. Original invoice line quantities are not overwritten; each item now shows **Original Qty, Returned Qty, Remaining Qty** in Invoice View/Print A4 and Sales/Purchases PDF/Excel reports.
2. **Active returns only**. Returned quantities and amounts are calculated from `document_returns.status='POSTED'`, by `source_line_id`. Voided returns automatically stop counting; return edits recalculate totals. The same invoice line never gets counted twice due to joins.
3. **Invoice listings** show Original Value, Returned Value, Net Goods Value, Paid and original payment balance. Net Goods Value is a merchandise metric, **not necessarily a cash amount due** (refunds, later receipts and account credit are separate ledger transactions).
4. **New POS-style Return UI** for both Sales Return and Purchase Return: search original invoice, select variation/size/color/SKU, see original and previously returned quantities, choose a few lines or use **Full Invoice Return** for all remaining quantities. A partial return can use any non-negative quantity no greater than the unreturned invoice-line quantity.
5. Return form offers date, reason, Cash/Bank/Wallet refund method and amount. Walk-in sale refunds are automatically set to the selected returned value, consistent with existing business rules. Returns edit under the same Return ID, while previous stock and accounting effects are reversed and reposted atomically.
6. Return listing and Sales/Purchase Return reports include item variation details. Return report uses the invoice's selected unit (Roll, Gazz, Feet, Table Sheet, Piece, Packet etc.), not a different base-stock unit.
7. No changes to licensing, SBM branding, payroll, POS billing, payment accounts or receipt accounting. All previous regression tests are retained and `test/return_pos_quantities_test.dart` added to the GitHub workflow.

## Tests in this package

- Source SQLite schema successfully created in an in-memory database with foreign keys enabled.
- SQL sample tested: invoice 10 Double + 5 Single, return 3 Double + 2 Single -> remaining 7 / 3; cancel return -> 10 / 5; invoice returned summary updated; return-edit exclusion and variant labels verified.
- Original/Returned/Remaining quantity Sales report and Returns report SQL executed against sample SQLite data.
- Modified Dart files checked for balanced delimiters and quotes (not equivalent to a Dart compiler).
- `flutter analyze`, `flutter test` and Windows `.exe` build have **not** been executed in this environment. Do not treat the package as a production-tested release until GitHub Actions builds and tests it.

## Deployment

- Back up the working SQLite database and compiled Windows release.
- Unzip and commit **contents of `ShopDesk/`** to a new GitHub branch including `.github`.
- Run **Build ShopDesk Windows EXE (v0.9.14)** and confirm Analyzer, regression tests, Windows release, and ZIP artifact all succeed.
- On a test database, run Sale and Purchase examples for full returns, selected items, repeated partial returns, returned variation, Roll/Gazz/Table Sheet, cancellation and editing.
- Do not change the signed-license private PEM or upload it to the public GitHub repo.
