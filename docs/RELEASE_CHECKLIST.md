# ShopDesk — required acceptance and hardening checklist

## Engineering and safety
- [ ] Flutter Windows release compiles and starts on target Windows 10 hardware.
- [ ] `flutter analyze` and `flutter test` pass; automated UI and database migrations tested.
- [ ] Reliable SKU/category/attribute validation, archive restrictions and unit conversions (pcs/meter/ft/roll).
- [ ] Cover all transaction edits, voids, returns, corrections and payment allocations without ledger divergence.
- [ ] Overpayment and party advances accounted for explicitly; payment reversal/refund support.
- [ ] Inventories costed (weighted average/FIFO), negative stock cost reconciliation and COGS, P&L and Balance Sheet.
- [ ] Ledger running balances and opening balance handling confirmed for filtered date ranges.
- [ ] Payroll partial dues / outstanding salary / advance recovery across periods reconcile and can be reversed.
- [ ] Expenses: corrections, reversals, multiple payment methods and supporting receipts.
- [ ] Daily closing, audit log, database integrity check, backup restore drills, printer paper margins and XLSX rows tested.
- [ ] Currency rounding rules, fractional quantities and unit conversion verified.
- [ ] Accounts permissions and local access control, input validation, crash recovery, backup retention.
- [ ] Large datasets (10k+ products, 100k+ invoices) tested for responsive UI and pagination.
- [ ] High contrast/keyboard shortcuts, printing Urdu text if applicable, accessibility and installation testing.

## User acceptance tests
- [ ] Sale 5 when stock 0 -> stock -5; purchase 12 -> stock 7.
- [ ] Credit sale creates receivable; receipt lowers it.
- [ ] Credit purchase creates payable; supplier payment lowers it.
- [ ] Void reverses stock, party ledger and journal.
- [ ] Employee advances recover on payroll; payroll creates outstanding salary where unpaid.
- [ ] Reports filtered by product/category/date/customer/supplier export readable A4 PDF and Excel.
- [ ] Backup after active writes restores reliably on a clean Windows computer.
