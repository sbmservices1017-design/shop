# ShopDesk Pro v0.9.6 – Client Acceptance Checklist

## 1. Stock Adjustment

Open Stock > Adjust Stock. Select a product then its specific Size/Color/Design/Pack variation. Choose positive or negative change in the visible base stock unit and enter a reason. Confirm only the selected variation's balance changes.

## 2. Full Roll sales

For any normal roll variant, Sales POS should show Feet, Gazz and Roll as sell units. A ready-made Table Sheet Roll offers whole Roll or individual Table Sheet (not Gazz). Test 1 roll of 30 Gazz = 90 Feet. Selling 1 Roll deducts 90 Feet; selling 2 Gazz deducts another 6 Feet. Confirm stock returns/voids restore the correct base quantity.

## 3. Payroll date

Choose a payroll month/year and a separate date (YYYY-MM-DD). Example: payroll period 2026-09, payment date 2026-10-14. Confirm payroll table, employee ledger, and journal show the payment date; do not permit two payroll runs for the same employee and period.

## 4. Sale POS split tender

Create a Rs. 20,000 sale with Rs. 8,000 cash, Rs. 7,000 bank, Rs. 2,000 wallet. It should be Partially Paid with Rs. 3,000 receivable. Each cash/bank/wallet account ledger should show only its contribution. Under Sales invoice listing select Add Installment and receive Rs. 3,000 to a chosen account; status becomes Paid. Reverse that receipt and verify Partially Paid returns. Correct stock persists throughout.

## 5. Purchase POS split tender

Post a Rs. 4,800 purchase using Rs. 1,000 cash and Rs. 800 bank. Supplier Payable is Rs. 3,000. Later pay this exact purchase invoice Rs. 3,000 using Wallet/Bank. Supplier Payable becomes zero and account ledgers reconcile. Customer/supplier payments against a different invoice must not shift the allocation.

## 6. Printing

No automatic print dialog on saving either POS document. Invoice View / Print A4 remains manual.

## Critical known limitation

**Legacy invoice editor does not edit several payment methods on one invoice.** A split-tender invoice correction is currently rejected to avoid moving paid balances to one account. Dedicated multi-tender correction and complete Windows QA remain required. Do not use as production release until the Windows build and these scenarios pass.

## Verification

Source migration and static SQL schema tested with sqlite3 in this environment. Flutter analyzer, Flutter tests and Windows executable were **not run** here, since Flutter/Dart SDK is absent. The GitHub Actions workflow contains the Flutter regression suite.
