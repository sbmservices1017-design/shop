# Functional coverage — ShopDesk Flutter integrated source v0.3.1

This file is a release truth table. **A screen existing does not mean the module is production-complete.**

| Module | Included now (code paths) | Remaining before live shop rollout |
|---|---|---|
| Dashboard | Variant totals, today's sales, customer/supplier balances, latest invoices | Configurable widgets, validated profit summaries |
| Categories | Add, rename, archive | Category delete/merge restrictions |
| Custom fields | Define/edit category attributes; text/number/choice validation during variant creation | Dedicated choice-picker UI, bulk attribute editing |
| Products | Add/rename/archive product, add/edit/archive SKU; opening stock | Edit variant attribute values, bulk import, unit conversions |
| Stock | Sum stock movement ledger, negative balances, manual adjustments | Quantity precision enforcement, lots, cost valuation |
| Sales | Multi-item manual-price invoices, cash/credit/partial payment, negative stock, void reversal and line-specific returns | Discounts/taxes, payment allocations, invoice corrections |
| Purchases | Multi-item supplier purchases, stock replenishment, void reversal and line-specific returns | Freight/landed cost, purchase allocations, invoice corrections |
| Customers | Add/update/archive, balance, ledger, incoming payments | Statement print from detail, allocation/receipt void, advances handling |
| Suppliers | Add/update/archive, balance, ledger, outgoing payments | Statement print from detail, allocation/payment void |
| Expenses | Categories, expense capture, payment account, report, audited reversal | Expense corrections, attachments, recurring entries |
| Employees | Register/edit salary, advances, payroll with recovery, ledger | Attendance, payroll void, salary adjustments, complete due settlements |
| Accounts | Chart of accounts, cash/bank transfer, balanced journal for core transactions, trial balance | Journal correction, opening balances, closing period, stock cost-of-sales |
| Reports | 27 report options, some related filters, PDF, Excel and print | Report-specific advanced filters, aging, full BS/P&L, saved layouts |
| Backup | SQLite snapshot via VACUUM INTO | In-app tested restore, backup schedules, encryption |
| Security | SQLite single-machine constraints and optional read-only database integrity check | Operator login, audit review, roles/permissions, password management |

## Status

- Flutter SDK is not installed in the generation environment: **project cannot be certified as compiling, tested, or executable here**.
- Windows release is compiled on Windows using the included .bat/Actions workflow; all pages are designed to ship inside **one release folder/build**.
- Not safe to replace a live shop ledger until end-to-end acceptance tests and critical pending items pass.

## v0.4.0 additions

- Atomically replace sales/purchases using `reviseDocument` (original invoice VOID + corrected invoice POSTED; linked returns must be voided first).
- Edit category-defined SKU attributes, rename expense categories, archive employees.
- Report SKU, expense-category, amount range, stock sign and invoice payment status filters.
- Customer/supplier running-balance ledger with pre-period opening computation, A4 PDF/Excel export and printing; employee ledger direct export and printing.
- Customer/supplier balances optionally as of report end date.
- Two added Flutter regression tests for atomic bill correction and ledger running balance.
- Required specification: `FULL_REQUIREMENTS.md`. Status still development, not Windows-compiled.
