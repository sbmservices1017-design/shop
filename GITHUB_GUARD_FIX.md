# GitHub source verification fix — v0.4.3

**Cause:** The v0.4.2 workflow searched for `  });` followed by an exact LF newline and `  Future<void> recordPayment`. Windows Git checkouts may use CRLF, so that check fails even though the corrected code is present.

**Fix:** Line-ending-independent regex in `.github/workflows/windows-build.yml`, plus `.gitattributes` to normalize Dart and workflow files.

## FASTEST fix (existing GitHub repository)
1. Replace the repository root `.github/workflows/windows-build.yml` with this ZIP's file.
2. Upload `.gitattributes` to repository root.
3. Run the new `Build ShopDesk Windows EXE (v0.4.3)` workflow.
4. If the Verify step passes but Flutter Analyze fails, open **Static analyzer (fail on errors)** and copy the red lines.

**Important:** This patch fixes the **verification step only**. It does not certify a working Windows EXE or solve unseen Dart compile errors.

## ALL FILES option
Extract ZIP. Upload *contents* of the `ShopDesk` folder, not the folder itself, to GitHub repository root. Ensure `.github/workflows/windows-build.yml` is replaced.

## Verify original Dart closure
In `lib/store.dart`, `reviseDocument()` ends with `});` immediately before the next `Future<void> recordPayment(...)` declaration (allowing whitespace).
