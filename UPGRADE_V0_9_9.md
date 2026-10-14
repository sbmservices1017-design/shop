# ShopDesk Pro v0.9.9 — Client UI and Delete Controls

## POS Full-screen workspace

- Select **POS** from the Dashboard sidebar and the sidebar hides automatically.
- The POS fills the available desktop window, keeping the SBM Services footer.
- **Dashboard** (top left) returns directly to Dashboard (subject to view permission).
- **Back** returns to the previous accessible module.
- Sale and Purchase POS tabs remain available; existing split tender, variants and unit conversions are unchanged.
- Product list has a larger visible **Add to Cart** button, and the billing cart takes more width on desktop.

## Delete controls and accounting safety

Delete requires each module's `delete` permission. Confirmations appear first.

| Module | Action |
|---|---|
| Categories | Soft-delete unused category; active products must be deleted first |
| Products / variations | Soft-delete only when available stock is zero; posted invoices stay in history |
| Sales / purchase invoices | Cancel (void), atomically reversing stock and accounting. Payment allocations or active returns must be reversed first |
| Sale / purchase returns | Void return, reverse stock and ledger |
| Expenses | Reverse expense, keeping original in audit history |
| Expense categories | Hard-delete ONLY unused category (no expense references) |
| Customers / suppliers | Soft-delete only with zero outstanding balance; ledgers retained |
| Accounts | Soft-delete only custom GL-/PAY- accounts with zero balance; internal system accounts protected |

Existing audit history, license, payroll and database schema retained. No destructive database migration is included.

## Build and verify

1. Backup current working database and source.
2. Extract `ShopDesk/` contents to the repository root, including `.github`.
3. Run GitHub Actions **Build ShopDesk Windows EXE (v0.9.9)**.
4. Ensure analyzer and all regression tests pass, including `test/delete_actions_test.dart`.
5. On a demo database verify: full-screen POS, Dashboard/Back, set/roll sales, confirm/cancel deletion, ledger reconciliation.

**Build status:** Static project and ZIP checks only. Flutter SDK not available in authoring environment; Windows compile has to be verified via GitHub Actions.
