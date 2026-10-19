# ShopDesk Pro 0.9.11 — invoice / return corrections and owner reset

Based on v0.9.10. Upload the **contents of `ShopDesk/`** to a NEW GitHub branch, keeping your previous working ZIP and database backup. The compiled EXE has **not** been built in this environment.

## Changes

1. **Sales and purchase invoice Delete/Cancel:** Cancels a posted invoice atomically, reverses its stock and journal postings, hides VOID records from active invoice lists and recent POS invoices. Linked **POSTED returns must be cancelled first** (explicit error explains this). If later installments have been allocated, the allocation is removed while actual payment receipts remain as *unapplied customer/supplier credit*. These are not silently deleted or refunded.
2. **Invoice Edit:** Keeps the same invoice ID/number. Refreshes the list after save. Keeps split Cash/Bank/Wallet payment accounts and reallocates later installments up to the updated invoice total; excess becomes unapplied credit. Payment amounts must be changed through payment history, not the item editor. Cancel active returns before changing an invoice. Previously voided return lines remain in audit history and no longer break edit FK constraints. The live invoice displays only its current lines.
3. **Sales Return / Purchase Return:** Both lists show only posted returns. Buttons: **Edit Return, Ledger, Delete Return**. Edit preserves the return ID, allows item quantities, return date, refund, payment method, reason, and atomically reverses/reposts stock/accounting. Old details are stored in `return_revisions`. Delete voids the return with audit reversal, preserving historical data. Per-return ledger has dates, debits, credits, payment method, PDF, Excel, Print A4. Walk-in returns use journal lines when there is no party ledger.
4. **Accounts:** A **Date** column uses the account creation date. Legacy accounts receive their earliest journal date (or migration date when no activity exists). New payment and general ledger accounts record their creation dates.
5. **Settings → Clear Shop Database:** Admin-only, five-digit owner PIN, exact confirmation phrase `DELETE ALL DATA`, then final confirmation. Automatic consistent SQLite backup via `VACUUM INTO` is required before shop records are cleared inside an FK-safe SQLite transaction. PIN entered in UI is compared with an encoded hash, with a limited-attempt cooldown. The app retains registration/login users, settings/profile, active license, machine ID and trial anchor to prevent licensing circumvention. The live shop **business data** is cleared, including inventory, products, parties, payments, receipts, sales, purchases, returns, employees, payroll, expenses, journal/ledgers, and user-created accounts. Built-in accounts and default expense category are re-created. **RESTART** after clearing.

## Database migrations

`accounts.created_at`, `document_lines.is_current`, and `return_revisions` are additive; existing records are not deleted on upgrade. Live invoices use `is_current=1`; historic returned lines use `is_current=0` and remain for audit references.

## Verification

- SQLite CREATE TABLE/INDEX extraction: 39 statements, foreign keys enabled — PASS.
- Historic source return line preserved during invoice correction — PASS in SQLite simulation.
- Full business-table delete order with foreign keys enabled — PASS in SQLite simulation.
- Changed source Dart delimiter checks — PASS (not equivalent to Flutter analyzer).
- New Flutter regression test: `test/invoice_return_reset_regression_test.dart` — INCLUDED, **not executed** here.
- Flutter analyzer / Flutter tests / Windows EXE build — **NOT VERIFIED**, requires GitHub Actions.

The five-digit PIN alone is not strong protection: a public offline application can be analyzed or modified, especially with full filesystem/database access. The admin login, rate-limit, backup, and confirmation improve safety, but do not replace operating-system security. Do not publish a private license-signing key with this project.

## Windows acceptance checklist (after GitHub Actions is green)

- Create Sale and Purchase; cancel each; ensure they disappear from active lists, stock changes reverse and accounting remains balanced.
- Create Sale Return/Purchase Return; edit quantity, date, refund and payment account; verify the **same Return ID** and stock/ledger updates; delete and verify only audit/reversal history remains.
- Edit Sales/Purchases with original split payments, and with installments; verify same invoice number; payment accounts stay assigned and any excess receipt becomes unapplied credit.
- Edit invoice after previously voided return; verify archive references survive and active UI shows only new items.
- Accounts list shows Date; adding a new account shows today's creation date.
- On throwaway demo database, Settings → Clear Shop Database must refuse incorrect PIN; correct owner PIN must create backup before clearing shop records; restart and verify license/login preserved.
- Reconcile Reports (Sales Returns, Purchase Returns, customer/supplier ledgers) and stock totals with manual calculations.

Do **not** test destructive reset against your only real customer database.
