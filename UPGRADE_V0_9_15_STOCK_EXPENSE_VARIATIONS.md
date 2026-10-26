# ShopDesk Pro v0.9.15 — Expense Delete, Stock & Variations

Based on integrated Flutter v0.9.14 source. Existing POS, payroll, split payments, returns, licensing and SBM branding are retained.

## What changed

1. **Expense Delete** now uses the existing audited reversal (`voidExpense`) and hides reversed expenses from the active Expense list. Historical expense and offsetting journal entries remain available for the audit trail, and existing reports/dashboard already omit reversed expenses. Permission rules still apply.
2. **Stock Search** supports product, category, size, color, variation description and SKU plus a category filter.
3. **Stock Ledger**: each variation's Opening, Purchase, Sale, Return, Void/Cancel and Adjustment movements are shown chronologically with Date, Type, Reference, Stock In, Stock Out, Running Balance, Note. All quantities use the variation's **base stock unit** (e.g. Feet or Pieces).
4. **Stock Edit**: quantity correction, **reference purchase cost per base unit**, suggested selling price per base unit. Correcting physical quantity posts a signed stock ADJUST movement (reason required), never rewrites invoice/history. Editing price only creates an audit event, not a financial journal transaction and does not recalculate historical profit.
5. **Products & Variations**: adding a variation refreshes the Products screen locally instead of re-keying it from the Shell, preserving the current product and scroll position. Individual product panels include a **Filter Variations by Size** dropdown with counts.

## Upgrade / data

- Existing SQLite databases are migrated non-destructively by adding `variants.purchase_price` and `variants.sale_price` columns if absent (integer paisa; default 0). New databases already contain both columns.
- Prices are informational/reference values only. The POS still allows **manual invoice prices**, and historical documents are unaffected.
- No existing expense is physically deleted. Delete is an **accounting reversal**, so the audit remains accurate.

## Validation

- Included `test/stock_expense_products_test.dart` checks stock corrections, invoice price preservation, IN/OUT ledger and expense reversal.
- `flutter analyze`, `flutter test` and Windows build **have not been run in this environment**. Use GitHub Actions workflow (updated to v0.9.15), then test with a copy of demo DB before using on client data.
