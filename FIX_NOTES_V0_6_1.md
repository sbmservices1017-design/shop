# ShopDesk Pro v0.6.1 — static analyzer correction

## What failed in the screenshot
Flutter analyzer reported `The method verifyDatabase isn't defined for the type Store` at `lib/settings_hub.dart:83:43`.
The database verifier already exists in `lib/extensions.dart` as a Dart extension method (`ShopDeskExtendedOperations on Store`). The Settings Hub file lacked `import 'extensions.dart';`.

## Exact corrections
1. `lib/settings_hub.dart`: import `extensions.dart` to resolve `Store.instance.verifyDatabase()`.
2. `lib/settings_hub.dart`: rename the license button handler `activate()` to `activateLicense()`. This avoids unintentionally overriding Flutter `State.activate()` and the analyzer's `must_call_super` warning.
3. `lib/settings_hub.dart`, `lib/commercial_core.dart`, `lib/license_widgets.dart`: remove unused imports.
4. Update project/build version to v0.6.1 and add a source guard for the required import.

## Verification
- Source assertions, ZIP integrity, dependency/references cross-checks: performed locally.
- Actual Flutter analyzer, unit/widget tests and Windows compilation: NOT performed here (Flutter SDK unavailable).
- Existing SQLite schema and business logic: NOT changed.

## Installation
1. Make a backup of the current working DB and branch.
2. Upload *contents* of `ShopDesk/` to repository root in a new branch, including `.github`.
3. Run GitHub Actions `Build ShopDesk Windows EXE (v0.6.1)`.
4. Verify Analyzer, Tests, Build Windows release. On green, test the executable on a COPY of the shop database before live deployment.

You can also make just the 2-line essential fix in GitHub directly: add `import 'extensions.dart';` alongside imports in `lib/settings_hub.dart` and rename `activate()` to `activateLicense()` and its button callback.
