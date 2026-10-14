# ShopDesk Pro v0.9.8 — Payroll UI regression test correction

## Symptom
The GitHub Actions `ShopDesk database and UI regression tests` step reported **41 tests passed, 1 failed**:
`test/payroll_ui_test.dart: Advance recovery updates net salary and Pay Now in UI`.

## Root cause
The newer payroll form has four TextFields in order: payroll period, **salary payment date**, advance recovery, Pay Now. The regression test was still entering `5000` into positional TextField index 1, now the **salary date field**, and then expecting net salary to decrease. That was a stale test, not evidence of broken salary calculations.

## Fix
- Assign stable widget keys `payroll_period`, `payroll_salary_date`, `payroll_recovery`, and `payroll_pay_now` to the existing fields.
- Update the regression test to locate the recovery and Pay Now fields via keys, not positional indices.
- Assert salary date remains untouched, and verify 40,000 gross - 5,000 recovered = 35,000 payable; 30,000 paid leaves 5,000 due.
- No payroll posting, inventory, POS, accounting, licensing, database schema, or UI layout logic was changed.

## Check and build
The zip and source/text consistency checks were run locally. Flutter/Dart SDK is not installed here. GitHub Actions must still run `flutter analyze`, the full tests, and the Windows release build to verify this update.

**Upload the contents of `ShopDesk/`, not its enclosing folder.** Keep the owner private signing key out of the GitHub repository.
