# ShopDesk Pro v0.5.1 — GitHub analyzer fixes

## Errors visible in the GitHub screenshot

1. `lib/advanced_dashboard.dart`: unbalanced nested widgets in the dashboard metrics grid. This caused Dart's `Expected to find ...` parser error and a cascade of incorrect `value`/`i`/function errors. The dashboard widget was rewritten using explicit blocks and balanced widget constructors, preserving the same metrics and SQL queries.
2. `lib/commercial_ui.dart`: user management directly calls `Store.instance`, but the file did not import `store.dart`; added the missing import.

No existing SQLite database migration was added by this analyzer fix. Application data is not bundled or overwritten.

## Deploy to GitHub

1. Download and extract the ZIP. Open the included `ShopDesk` folder.
2. Upload/replace its **contents** into the repository ROOT (the same level as `pubspec.yaml` and `lib/`). Include the hidden `.github/workflows/windows-build.yml` path.
3. Keep an untouched copy of the previous working source and backup the SQLite database before installing a new binary.
4. Run GitHub Actions workflow **Build ShopDesk Windows EXE (v0.5.1)**.
5. Look for a green **Static analyzer (fail on errors)** step. Then allow the regression tests and Windows release steps to run.
6. Download the entire Windows release artifact (EXE + DLL/data), not just the EXE.

## Verification status

- Edits applied to v0.5.0 source.
- Dashboard widget delimiter balance and the missing import were checked locally.
- ZIP structural validation was performed.
- **Flutter analyze, Flutter tests, Windows compilation and real desktop QA could NOT be executed in this environment**. If the next Actions run reports further errors, share the *first red error and ~15 following lines*; that output will identify additional changes required.
- The project's previously documented production gaps (inventory costing, comprehensive backend authorization, complex payroll and returns QA) are NOT solved by this build-error patch.
