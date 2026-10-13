# ShopDesk — Complete Software Requirements Specification
**Single-PC Windows | Flutter | Offline SQLite**

**Scope rule:** The requirements below are the agreed target specification. A requirements file does not certify that the accompanying development source is a finished or Windows-tested executable.

## Quick operating flow
Create Category → Define Custom Fields → Create Product/Variant → Enter Opening Stock → Purchase/Sale → Post Ledgers → Report / Export / Print

## 01 | Product Vision & Environment
- One complete Windows desktop application for a single retail shop that sells mattresses, door mats, chatai, floor paper, table sheets, blankets and any future product types.
- Flutter Windows frontend with a modern, responsive desktop interface and one local SQLite database; internet access is not required for daily operation.
- All modules must be accessible inside the same application and ship in one Windows release bundle / installer—not as separate apps.
- Primary objective: simple stock control and manual billing, with linked purchases, parties, ledgers, expenses, employees, accounting and rich reporting.
- Default currency PKR; monetary values stored with exact minor-unit precision. Calendar dates, invoice numbers, transaction timestamps and audit history must be retained.

## 02 | Dynamic Categories, Products & Variations
- Unlimited categories and subcategories; rename, archive and search categories while preserving historical documents.
- Unlimited products with product names, category, optional SKU/barcode, active/archived state and optional notes.
- Category-specific custom attributes that shop staff can create without changing software code: text, numeric, choice/dropdown, dimension and other valid types.
- Examples: Mattress—size, brand, thickness, density, foam type; Door Mat—color, size, material, design; Chatai—length, width, quality; Floor Paper—roll width, length, design; Blanket—single/double, material and weight.
- Product variations represent individually tracked sellable SKUs; each SKU has its own unit and independent stock balance.
- Attribute choices and validation can be edited; product/variation attributes can be updated safely without rewriting posted invoices.
- Units such as piece, roll, meter, foot, yard, packet and set; unit conversion mapping is required when purchases and sales use different units.
- Fast search by name, SKU, barcode, category, custom field and variation; archived stock remains reportable in history.

## 03 | Stock & Inventory Ledger
- Opening quantity per variation; stock adjustments with reasons; damage, shrinkage, disposal, returns, transfers (if future locations added) and historical movement journal.
- One source of truth: live stock = opening quantities + purchases + sale returns + positive adjustments - sales - purchase returns - negative adjustments.
- Negative stock is explicitly allowed for sales: saving a bill must NOT fail merely because current stock is zero or less than ordered quantity; display a warning instead.
- Example: opening 0, sell 5 => -5; later purchase 12 => 7. Do not create replacement SKU just because its stock is negative.
- Quantities may have up to three decimal places where the unit supports partial quantities; invalid/NaN quantities must be rejected.
- Atomic posting: sale/purchase, party ledger, journal and stock movements all commit together or all roll back together.
- Stock views: per variation, category, low/zero/negative, stock as of selected date, movement source, period and adjustments.
- Inventory costing policy must be selected and implemented (weighted-average or FIFO) before showing authoritative stock value or gross/net profit, especially when negative stock is allowed.

## 04 | Sales & Manual Billing
- Manual invoice creation with transaction date, optional customer for walk-in cash sale, multiple product variations, quantity, per-line manually entered price and optional notes.
- Selling price must never be forced from a saved product price; different customers and every bill may have different rates.
- Bill calculates line totals, final total, amount paid now and remaining balance; cash, bank, credit and partial payments are required.
- Credit/partial sale must be linked to a customer; customer receivable updates when bill is posted.
- Save bill even when stock turns negative; post exact negative quantity against the selected SKU.
- Invoice lists, search, date filter, detail view, A4 invoice print, PDF and optional bill export.
- Invoice correction/edit must safely reverse original entries and post corrected invoice atomically, preserving original invoice number in audit history; no destructive silent rewrite.
- Cancellation/void and sales returns must reverse the applicable stock, accounts and party ledgers; returns support item-level partial quantities and refund/credit.
- Optional future enhancements: line discount, invoice discount, tax and configurable receipt formats. These must not be assumed as complete until tested.

## 05 | Purchases & Suppliers
- Supplier register: name, contact, phone, address, opening balance, active/archived status, purchase history and outstanding amount.
- Purchase invoice supports supplier, date, multiple SKUs, quantity, manually entered unit cost, total, paid now, due and reference.
- Confirming a purchase increments stock for exactly the selected SKU; purchases repay a negative stock balance automatically.
- Supplier credit/partial payment increases payable balance; later payments reduce payable balance.
- Supplier return supports original purchase line, partial return quantity, stock reduction, refund and ledger reversal.
- View/print/export supplier ledger with dated debits, credits and running balance; payment history, adjustments and opening balances.
- Purchase corrections/void must recalculate quantities and supplier payable without duplicates; keep audit trace.

## 06 | Customer Register & Receivables
- Customer register with name, phone, address, optional notes, opening balance, paid/credit history and statement.
- Customer detail offers View Ledger, Add Payment, Payment History, Edit, Archive and A4/PDF/Excel export.
- Customer receivable = total customer debits minus credits; advance payments/credit balances remain visible and distinct from amounts due.
- Report customer balances as of selected date; show running balance, transaction references, invoice links, receipts and refunds.
- Receipt or payment edit/cancel must reverse its posting with an auditable entry; not silently delete linked history.

## 07 | Expenses & Categories
- Unlimited expense categories such as rent, utilities, transport, maintenance, wages and miscellaneous; rename and manage categories.
- Expense entry: date, category, amount, cash/bank account, description and optional reference/receipt attachment.
- Expense report must filter by date, category, payment account, amount range, text search and transaction status.
- Every approved expense posts to expense/cash or bank accounts. Corrected or cancelled expenses reverse related journal entries with audit history.

## 08 | Employees, Salaries, Advances & Ledger
- Employee details: full name, designation/role, start date if provided, monthly salary rate, active/archived status and notes.
- Advance payment made to an employee is saved immediately against both employee advance ledger and selected cash/bank account.
- Payroll by employee and YYYY-MM period: gross salary, outstanding advance, recovery amount, other approved deductions, pay now and unpaid salary.
- Advance recovery cannot exceed either available advance or salary; unadjusted advance carries forward.
- Part-pay or defer salaries; later payment of outstanding salary reduces Salary Payable and cash/bank balance.
- One employee ledger showing advances, recoveries, gross salary dues, paid amounts, adjustments and running advance/salary balances.
- Protect against duplicate payroll for the same employee/month; allow controlled correction/reversal with an audit trail.
- Employee register, salary report, advance report and employee ledger all export/print in A4/PDF/Excel.

## 09 | Financial Accounts & Double Entry
- Chart of accounts: Cash, Bank, Accounts Receivable, Inventory, Employee Advances, Accounts Payable, Salary Payable, Equity, Sales Revenue, Cost of Sales, Operating Expenses and Salary Expense.
- Cash/bank payments, transfers, receipts and balanced manual journal entries with references and dates.
- Sales, purchases, returns, receipts, payments, expenses, employee advances and payroll produce balanced accounting postings in the same transaction as source records.
- Opening balances for customers, suppliers, cash/bank, inventory and chart of accounts with proper balancing equity entries.
- Trial balance, account ledger, cash/bank book, revenue/expense summary and reconciliation controls.
- Full profit-and-loss, inventory valuation and balance sheet require complete and verified inventory COGS and closing rules; they must never be labelled final based on revenue minus operating expenses alone.
- Posted transactions must be voided/reversed rather than hard-deleted; account numbers and historical journals must remain immutable.

## 10 | Reports — Mandatory Catalogue
- Sales report: invoice, item, category, variation, customer, payment status, date, amount and totals.
- Purchase report: supplier, item, category, variation, cost, paid/due, date and totals.
- Customer list and Customer Ledger (running balance), Customer Receivables / outstanding aging, customer payments.
- Supplier list and Supplier Ledger (running balance), Supplier Payables / outstanding aging, supplier payments.
- Expense summary and category-wise expense reports, employee register, employee ledger, payroll, salary outstanding and advances.
- Stock by product/category/variation, negative/zero stock, stock movements, stock as of selected date, opening and stock adjustment history.
- Product and variation register; sales returns, purchase returns, account ledger, cash/bank report, trial balance, daily/monthly sales, audit trail.
- Profit & Loss, Balance Sheet, inventory valuation and COGS become deliverables only after cost accounting acceptance is completed.

## 11 | Reports — Filters, Export & Printing
- All reports offer only meaningful filters from: custom start/end dates, today/week/month/year, product, SKU variation, category, customer, supplier, employee, expense category, account, cash/credit status, negative/zero/positive stock, invoice number, search text and min/max amount.
- Group/sort when meaningful by day, month, product, category, customer, supplier, account or payment status; no fabricated groupings for incompatible reports.
- Filter controls are dynamic for each report; changing filters must regenerate preview and totals, not merely hide rows in a table.
- Export the filtered results to native Excel .xlsx and PDF; use A4 page formatting for PDF and Windows print.
- Portrait for narrow reports, landscape for wide reports; repeated column headers, page numbering, consistent company heading, date range, readable currency and safe row pagination.
- Preview can paginate large reports but export must include ALL filtered rows. Numeric columns remain numeric in Excel if feasible.
- Customer, supplier and employee detail screens provide direct ledger export and print shortcuts.

## 12 | UI/UX & Accessibility
- Professional Flutter desktop interface: single consistent dark navigation rail/sidebar, light content workspace, search, dashboards, forms and tables.
- Consistent input validation, spacing, typography, confirmation dialogs and error messages across every module.
- Desktop-friendly keyboard and mouse interaction: tab order, keyboard shortcuts where practical, sortable table headers, focus indicators, scrollable wide tables.
- Never create an apparently working button without implementation; error messages must explain the action and preserve entered form state where possible.
- Dashboard tiles for today sales, total SKUs, zero/negative stock, customer receivables and supplier payables; do not label revenue as profit.
- Business-critical actions (void/refund/return/correction/restore) need confirmation and clear consequences.

## 13 | CRUD, Audit & Data Integrity
- Create, read, update and archive for product groups, products, variations, customers, suppliers, employees, expense categories and user-editable settings.
- All posted transactions support auditable correction/void/return with compensating entries; hard delete of financial records is prohibited.
- Stock and general-ledger journals use foreign keys, constraints, prepared query arguments and atomic SQLite transactions.
- Reject invalid amounts, non-finite numbers, incorrect parties, invalid date formats and excess returns; do not reject valid negative stock.
- Maintain audit timestamps and old/new record identifiers for corrections; preserve historical reports and transaction references.
- SQLite foreign key checks, integrity_check, journal debit-credit equality and returns quantity controls available in a diagnostics screen.

## 14 | Backup, Restore, Security & Packaging
- Single-PC offline storage in Windows application-support directory, not inside a temporary unzip folder.
- One-click consistent SQLite snapshot backup, date-stamped filenames and clear data location.
- Validated restore process while app is closed; preserve previous database and test restored checksum/integrity prior to replacement.
- Automatic backup schedule and off-device copying recommended; encryption and sign-in/access controls specified for hardening when live finance records will be stored.
- Generate one Windows release build containing all Flutter modules. Include runtime DLLs/data, installation instructions and desktop shortcut / installer if requested.
- All scripts/CI must run flutter create --platforms=windows ., flutter pub get, flutter analyze, flutter test and flutter build windows --release; release only if those steps pass.
- Provide user-facing installation, operation, backup and troubleshooting manual; production rollout requires trial with copy of real shop stock and balances.

## 15 | Core Workflow Acceptance Tests
- AT-01: Create new category with user-defined size/thickness/brand fields, then create two SKUs with different attributes and independent opening quantities.
- AT-02: With zero stock, sell 5 SKU units at user-entered unit price: bill saves and stock becomes -5, with linked customer ledger if credit.
- AT-03: Purchase 12 of same SKU from supplier: stock becomes +7; supplier payable and journal reconcile.
- AT-04: Correct posted invoice quantity/price or party: old invoice voided, new invoice posted atomically; failed correction leaves original untouched.
- AT-05: Partially return sold goods; exact line quantity restored; customer refund/credit and journal updated, no excessive returns possible.
- AT-06: Partially return purchased goods; correct stock reduction and supplier refund/credit.
- AT-07: Customer buys on credit, makes multiple receipts and has a running ledger with correct opening, debit, credit and current balance.
- AT-08: Supplier purchases on credit then is paid partially; supplier payable drops by payment amount without changing stock.
- AT-09: Enter and reverse expense; expense-category report and cash/bank journal match.
- AT-10: Employee takes advance, payroll recovers some, unpaid salary is settled later; employee advance and salary due are correct.
- AT-11: Apply date/category/product/variant/customer/supplier/employee/payment-status and negative-stock report filters; result counts and totals match raw records.
- AT-12: Export long/wide reports to Excel/PDF and print A4 with repeated headers; all filtered rows present.
- AT-13: Verify SQLite integrity, all journal postings balanced, and original posted transaction history preserved after correction/void.
- AT-14: Back up database, restore in a safe test location, reopen and compare customer balances, supplier balances and stock against source.
- AT-15: Build and launch the Windows release on the target computer; test full purchase -> sale -> payment -> return -> report workflow.

## 16 | Delivery Definition of Done
- The delivered release is ONE Windows desktop application with all required modules wired to one durable SQLite database.
- Every module has tested create/edit/archive (masters) or post/correct/void/return (financial) flows and helpful error states.
- Negative stock behaviour remains enabled and does not block a valid invoice.
- Full report/filter matrix supports tested Excel export, PDF and A4 printer layout.
- Financial valuation, closing and profit-related pages are either verified or explicitly disabled and labelled incomplete.
- Automated Flutter tests, Windows analyze, Windows release build, installer smoke test and sample-data acceptance checklist are completed without errors.
- Shop staff receive an operational walkthrough, backup/restore procedure and a method to report any bugs before using live accounts.

## Report Filter Matrix
| Report | Applicable filters |
|---|---|
| Sales / billing | Date, customer, product, SKU, category, payment status, range, invoice |
| Purchases | Date, supplier, product, SKU, category, payment status, range |
| Stock / negative / as-of | As-of date, product, SKU, category, negative/zero/positive |
| Stock movements | Period, product, SKU, category, source |
| Customers / receivables | Customer, as-of date, name search, aging |
| Customer ledger | Customer, date range, running balance, transaction reference |
| Suppliers / payables | Supplier, as-of date, aging, name search |
| Supplier ledger | Supplier, date range, running balance, transaction reference |
| Expenses | Date range, category, cash/bank account, amount range, search |
| Employees / payroll | Employee, period, dues, advance, role |
| Employee ledger | Employee, period, entry type |
| Accounts / cash bank / trial balance | Account, date range, reference, account type |
| Products & variants | Category, product, SKU, custom values |
| Returns, receipts & audit | Date, reference, party, status, employee where relevant |

## Source delivery and verification status
**Not yet certified as complete:** Flutter toolchain and Windows compiler were unavailable in the preparation environment. The source requires successful `flutter analyze`, `flutter test`, Windows release build and on-device acceptance before live shop use.
Full COGS/cost valuation, payroll correction, production-grade permissions/restore and other release-hardening issues require further implementation/verification.
