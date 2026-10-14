# ShopDesk Pro v0.9.0 — Client requested upgrade

This source version extends the existing v0.8.2 SBM-branded desktop application. It does not replace the previous products, customers, suppliers, employee/payroll, accounts, license, security or reporting modules.

## 1. Multi-unit inventory and POS

Each existing variant/SKU has ONE canonical stock unit (`variants.unit`). Examples:

- Floor sheet (SKU `FLOOR-A`, base unit `ft`): buy 2 rolls where 1 roll = 100 ft → stock +200 ft; sell 5 gazz with 1 gazz = 3 ft → stock -15 ft, leaving 185 ft.
- Door mat (SKU `MAT-RED`, base unit `pcs`): buy 4 packets where 1 packet = 12 pieces → stock +48 pcs; sell 7 pieces → stock -7 pcs.
- Size / Color / Design: remain separate named attributes on distinct variants, each with its own independent stock balance. Product selection in POS now opens a variation chooser when a product has multiple variants.

Configure mappings from **Products → Variants & Stock → Purchase / Sale Units**. You can enable units for purchase only, sale only, or both. The sale conversion factor is checked against configured definitions; purchase unit factor can be overridden for a supplier packet/roll containing a different actual quantity. Quantity and manual rate shown on the invoice are **per selected sale/purchase unit**, while stock movements use the canonical base unit. The conversion factor and selected unit are snapshotted with the invoice line.

> Gazz/yard is configurable; check the client’s actual local measurement, not an assumed universal standard. For example, set 1 gazz = 3 ft only if that is the shop's agreed rule.

### Existing data

The migration adds SQLite tables but does **not** multiply or rewrite any historical quantity. Old invoice lines default to factor 1, preserving historical stock. A live variant's canonical unit must not be changed after stock movements have been recorded. For existing products recorded in rolls but now needing feet-based stock, first back up, then plan an inventory reconciliation or create a separate feet-based SKU with approved opening quantities. Do not simply relabel `roll` to `ft`.

### Returns and corrections

Returns and void/reverse movements multiply the returned quantity by the original invoice line's snapshotted factor. Invoice edits retain the same invoice ID and serial number. Changing a conversion after an invoice was created does not retroactively revalue the original invoice.

## 2. No automatic print prompt after saving from POS

The saving action creates the bill, updates stock and ledger, displays a snackbar, and resets the cart. There is no print confirmation popup. The user can print or export invoices later from the Sales or Purchases invoice listing.

## 3. Custom payment accounts

Go to **Accounts → Add POS payment account** and enter an account code, label and type (`Cash`, `Bank`, `Wallet`). Newly created accounts automatically appear in POS payment methods and the existing collection, expense, salary and supplier payment selectors. All payments post debit/credit entries to that selected account. **Accounts → View Ledger** shows date, source, debit, credit and running balance, with Excel, PDF and A4 printing.

`payment_accounts` are restricted to approved asset accounts. Initial Cash and Bank accounts are migrated automatically. Accounts used historically should be archived instead of hard deleted.

## 4. Recommended acceptance checks on a BACKUP database

1. Existing stock, invoices, payroll, licensing, branding and reports remain intact after database migration.
2. 2 rolls × 100 ft = 200 ft stock; sale of 5 gazz × 3 ft = 15 ft out; balance 185 ft.
3. Return of 1 gazz = 3 ft in; void that return = 3 ft back out; void sale restores 15 ft; void purchase removes 200 ft.
4. 4 packets × 12 pcs = 48 pcs stock; sale 7 pcs leaves 41.
5. Size/color variation pick modifies only that SKU; other sizes/colors are unchanged.
6. POS save completes WITHOUT printer popup for purchase and sale.
7. New cash/bank/wallet account appears in payment dropdown; receipts and payments post to its ledger.
8. Invoice print, PDF and Sales/Purchases report display the selected unit (not incorrectly always `ft` or `pcs`).
9. Attempting to change canonical unit on an SKU with historical stock transactions is rejected.
10. Run Flutter analyzer, database regression tests, then GitHub Windows build. Finally verify UI and backup/restore on Windows 10/11.

## Verification status

Flutter toolchain is not available in the authoring environment, so Windows EXE compilation and Flutter tests are NOT verified. Static source and SQLite schema/simulation can pass without guaranteeing that the app compiles. This version is development source; do not replace a live shop installation without successful QA and backup restoration.
