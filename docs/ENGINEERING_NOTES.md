# ShopDesk v0.3 Engineering notes

## Release truth
This is one integrated Flutter application **source tree** for Windows. Every major module has a page and SQLite-backed operations, but it is **not a validated release** or safe for live bookkeeping yet. `flutter analyze`, `flutter test`, and a real Windows build are required. Source generation here did not have a Flutter SDK or Windows toolchain.

## Single-computer architecture
- Flutter + Material 3 GUI; SQLite database stored in the Windows app-support directory.
- Variant-level stock ledger; allow negative balances when sales exceed current stock.
- Sales/purchases use cash/credit/partial and the operator manually enters each transaction's price.
- Operational documents, financial journal, party ledger, and stock movements are updated in a single transaction; cancellations post reversing entries.
- People modules include customers, suppliers, employees; cash/bank accounts; advances and payroll.
- Reports can be filtered by date, product, category, party and employee where relevant; PDF is A4 and Excel is XLSX.

## Production blockers
1. Reliable perpetual inventory costing, cost of goods sold, and **genuine** P&L and balance sheet, especially with negative stock.
2. Proper edit-in-place or audited correction flows across *all* document types (void-and-reissue is available for some).
3. Complete invoice-to-payment allocation, customer/supplier advance treatment, aging and due-date handling.
4. Consistent unit-conversion calculations (roll -> meters, feet -> meters), rather than only unit label support.
5. Backup **restore with validation**, automated retention, restore drills and database migrations.
6. Role-based logins, authorization and access audit, privacy and workstation hardening.
7. Payroll reversal, accrual dates, outstanding balances/advance carry-forward reconciliation.
8. A4 invoice branding and localized bill templates, printer tests, and PDF pagination on large datasets.
9. Scale/keyboard/UX testing with typical retail datasets and Windows packaging acceptance.

## Windows compilation instructions
On a Windows computer with Flutter and Visual Studio C++ desktop workload:
```
flutter create --platforms=windows .
flutter pub get
flutter analyze
flutter test
flutter run -d windows
flutter build windows --release
```
Distribute the full Release folder, not just its executable. The included GitHub Actions workflow attempts the same steps and produces a ZIP artifact *if* compilation and tests pass.
