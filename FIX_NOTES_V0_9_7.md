# ShopDesk Pro v0.9.7 — Analyzer fix

Based on the complete ShopDesk Pro v0.9.6 ZIP.

## Source corrections
1. `lib/modern_pos.dart`: remove one extra `)` when closing the split-payment `ListView.builder` itemBuilder. Keeps its payment UI and business logic unchanged.
2. `test/v0_9_6_shop_changes_test.dart`: provide `packing: 'piece'` and `packSize: 1` for the Mattress variation; provide `packSize: 1` for the Table Sheet Roll variation. Required arguments now match `Store.createSimpleVariant`.
3. Update version/build workflow label; retain all source guards, Flutter analyzer, regression tests, and release artifact uploads.

## Testing status
- The modified files were syntax-delimiter checked with a local static script.
- Required-argument call sites were checked.
- ZIP integrity checked.
- `flutter analyze`, `flutter test`, and Windows compilation **must run in GitHub Actions** because the Flutter SDK is not available in this environment.
- Nonfatal lints/warnings may remain; the build must not suppress analyzer errors.

## GitHub upload
Extract the ZIP and upload the **contents** of its `ShopDesk/` folder to the repository root, including hidden `.github/workflows/windows-build.yml`; commit and check GitHub Actions.
