# ShopDesk GitHub analyzer fix — v0.4.2

## Why the screenshot failed

The previous v0.4.1 archive contained two genuine errors in `lib/store.dart` and one in `lib/main.dart`:

1. `_postDocumentTxn` referenced `total` and `money` declared in a DIFFERENT function. Both must be defined inside `_postDocumentTxn`, from the validated items and amount paid.
2. `reviseDocument` was written as `async => db.transaction((t) async { ...` but ended in `}` rather than `});`. This parser error caused a cascade of false `undefined_method` errors for `recordPayment`, `addExpense`, `addEmployee`, `employeeAdvance`, `payrollRun` and others that occur later in the class.
3. `lib/main.dart:393` embedded `r.kind='expense'` in a single-quoted Dart SQL string, creating parse errors. It now uses a double-quoted Dart string for the query.

The v0.4.2 source fixes both errors and removes a cosmetic dangling-library-doc warning.

## Replace old GitHub files carefully

1. Extract **this** ZIP.
2. Open the `ShopDesk` folder INSIDE the extracted archive.
3. Upload **all the contents** of that folder into the **root of your existing GitHub repository**, using overwrite/replacement. `.github/workflows/windows-build.yml` must also be replaced (the `.github` folder is often hidden).
4. Verify in GitHub that `lib/store.dart` begins with `// Build source revision: SHOPDESK_SOURCE_0_4_2_ANALYZER_FIX`.
5. GitHub > Actions > **Build ShopDesk Windows EXE (v0.4.2)** > Run workflow. Watch for step **Verify corrected ShopDesk sources were uploaded**, then Static analyzer, tests, Windows build.
6. On success, download `ShopDesk-Windows-Release`; keep the EXE with its sibling `.dll` and `data` files.

If GitHub shows the old workflow name or complains about OLD SOURCE, the replacement did not reach repository root. If analyzer fails again, send the FIRST red error and its full message; **do not ignore errors**.

## Verification limits

- These source changes were inspected statically, and extracted SQL schema smoke checks can be performed locally.
- The Flutter SDK and Windows compiler are NOT installed in this environment. We cannot truthfully claim a passing Flutter analyzer, unit tests, or a compiled EXE from this sandbox.
- This fixes the build blocker, **not** outstanding production accounting/valuation/security gaps in the v0.4 application.
