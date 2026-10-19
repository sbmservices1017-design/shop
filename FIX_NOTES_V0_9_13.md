# ShopDesk Pro v0.9.13 — Invoice correction / split-payment regression fix

This update is based on v0.9.12 and preserves existing POS, returns, stock,
accounts, payroll, licensing, SBM branding, and keyboard shortcuts.

## Fixed transaction behavior

1. An invoice created with zero or one initial payment and **no later installment**
   can have its initial paid amount corrected through the same-invoice editor.
   This is an audited correction of an entry mistake: the old journal / party-ledger
   posting is reversed, the edited payment posts under the selected account,
   and the original invoice ID and number remain unchanged.
2. If an invoice has multiple Cash/Bank/Wallet payment parts or later allocated
   installments, the single `paid` field must match the recorded sum. Edited
   items/rates can still be saved, but individual payment records and account
   selections cannot be silently rewritten. Payment corrections require the
   payment-history / reversal workflow.
3. The older v0.9.6 regression expectation that multi-tender invoice item
   correction MUST fail was no longer valid after newer split-payment support.
   Its test now checks: incorrect paid-total is rejected, unchanged split parts
   are preserved after invoice correction, invoice ID is unchanged, and void
   restores stock.
4. The single-payment test now verifies total, paid, active payment part,
   receivable balance, revision count, original number, and stock reversal.

## Validation

Performed in this environment: source patch inspection, Dart delimiter
structural checks, ZIP integrity check, and a SQLite journal-and-stock model
of the correction/void invariant. No Flutter SDK or Windows compiler is
available here: **flutter analyze, flutter test, and the Windows EXE build
have NOT been executed**. GitHub Actions must confirm these steps.

## Build

Upload the contents of `ShopDesk/` to a new GitHub branch, replacing older
files. Run the included GitHub Actions workflow for v0.9.13.
Do not overwrite a production database until tests and a backup/restore drill
succeed in the compiled desktop app.
