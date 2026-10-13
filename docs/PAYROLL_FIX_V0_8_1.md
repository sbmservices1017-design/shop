# Payroll & Employee Advance Fix (v0.8.1)

This update **keeps existing ShopDesk modules intact**. Changes are limited to employee payroll presentation, payroll validation, regression tests and Windows workflow versioning.

## Correct workflow

1. Add employee (monthly gross salary Rs. 40,000).
2. Give an advance of Rs. 5,000 from cash/bank. Employee advance balance becomes Rs. 5,000.
3. Choose **Run payroll**, choose the monthly period, enter **Advance recovery: 5,000**.
4. **Pay now** automatically changes from Rs. 40,000 to **Rs. 35,000** unless manually overridden for a partial payment.
5. Save. Net salary Rs. 35,000, outstanding advance Rs. 0, outstanding salary Rs. 0.
6. For a partial payment (e.g. Rs. 30,000), salary due remains Rs. 5,000 and can be settled with **Pay salary due**.

### How to avoid duplicate / incorrect payroll

- `Pay now` is cash actually disbursed in this payroll, not the pre-deduction gross salary.
- Once a monthly payroll is posted, the same month cannot be run twice.
- No partial ledger/journal insert remains after an invalid transaction (SQLite transaction rollback).
- The original salary remains in the employee record; per-month gross/recovery/net/payment are kept in payroll history.

## Validation

- Tests added for full recovery+net pay, partial pay+settlement, erroneous gross overpayment, balanced journal entries, and repeated period rejection.
- Not compiled here: run the included GitHub Actions workflow to verify Flutter analyzer, unit tests, Windows bundle build.
- Test on a **database backup**, not a live production database. Do not overwrite the original SQLite file while the application is open.

## Files changed

- `lib/store.dart`: clearer amount/duplicate period validation, uses shared payroll quote.
- `lib/payroll_math.dart`: central net-pay computation in integer paisa.
- `lib/payroll_dialog.dart`: dedicated reactive payroll form.
- `lib/main.dart`: connect new dialog to existing employee screen.
- `test/store_test.dart` and `test/payroll_math_test.dart`: regression coverage.
- `pubspec.yaml`, `SOURCE_VERSION.txt`, `.github/workflows/windows-build.yml`: version/check updates.
