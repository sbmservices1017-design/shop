# v0.9.1 GitHub Actions static-analyzer fix

## Failure

`test/store_test.dart`: `Arguments of a const creation must be constant expressions` at ItemLine constructors used inside roll/gazz/packet tests.

`vid` is created by `await s.addVariant(...)` so is a runtime value.

## Correction

Removed `const` from the THREE `ItemLine(vid,...)` calls. Test behavior is unchanged. No changes to business logic, database schema, or production source in `lib/`.

## Steps

1. Extract ZIP and upload contents of `ShopDesk/` into a new GitHub branch/repository root.
2. Commit `test/store_test.dart`, `pubspec.yaml`, `SOURCE_VERSION.txt`, `.github/workflows/windows-build.yml` and docs.
3. Run GitHub Actions and confirm analyzer, regression suite, Windows compile succeed.
4. Preserve the existing working EXE and SQLite backup until the Windows release is tested.

## Verification limits

No Flutter SDK/Windows compiler available here; cannot claim that the full pipeline has passed.
