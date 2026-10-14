# ShopDesk Pro v0.9.10 — Ledger payment methods, compact POS, credit dashboard

## Ledger
- Customer/Supplier ledger: visible Payment Method column on invoice, Cash/Bank/Wallet payments, subsequent installments and reversals. Non-cash invoice charge displays Credit / Non-cash rather than inventing a cash account.
- Split tender creates an individual ledger entry for each payment account, while maintaining total balance.
- Employee and account ledgers also expose Payment Method. Cash & Bank/Wallet account names remain as configured.
- Old SQLite databases migrate safely: party_ledger gets nullable payment_account_id. Old records remain, and reports use legacy payment-part / receipt account lookups when possible.
- PDF/Excel/A4 ledger report exports automatically include the new column.

## POS
- Compact cart with product + variation, Unit, Qty, Rate, Amount in one row.
- Newly added item moves to the TOP; most products fit without nested scroll on desktop.
- Persistent large cart section and resizable/collapsible payment detail section. If cart has more items than physically fit, scrollbar remains available and prominent.
- Existing manual prices, split payments, unit conversion, stock movement, status and full-screen POS behavior retained.

## Dashboard
- New fifth KPI card: Customer Credit Due. This is the current unpaid amount for posted SALES invoices in the selected dashboard date range.
- Clear Date Filter restores live rolling 30-day period; 5-second refresh continues.
- Receipt installments reduce Customer Credit Due. Supplier payables remain separate.

## Build and verification
- Existing GitHub Actions checks remain, plus test/ledger_payment_credit_test.dart.
- Source static and SQLite fixture tests can be verified here, but Flutter Windows SDK is not installed. Run Flutter analyze/test/build in GitHub before production use.
- Back up SQLite data before upgrade.
