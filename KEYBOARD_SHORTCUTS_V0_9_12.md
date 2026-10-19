# ShopDesk Pro v0.9.12 — Keyboard Shortcuts

This is the full v0.9.11 codebase with keyboard shortcuts added. All existing
invoicing, returns, ledgers, data reset, split payments, salary and branding code remains.

## Navigation (available after login; view permissions enforced)

| Keys | Action |
|---|---|
| F1 | Open keyboard shortcut guide |
| F2 / Ctrl+2 | Full-screen POS |
| F3 / Ctrl+3 | Sales invoices |
| F4 / Ctrl+4 | Purchase invoices |
| F5 | Refresh screen (asks before discarding an unfinished POS cart) |
| Ctrl+K | Search/navigation for authorized modules |
| Ctrl+1 | Dashboard |
| Ctrl+5 | Products & Variations |
| Ctrl+6 | Stock & Adjustments |
| Ctrl+7 | Customers |
| Ctrl+8 | Reports / Export |
| Ctrl+9 | Settings & Backup |
| Alt+Left | Leave full-screen POS and return to the previous module |

## Inside the full-screen POS

| Keys | Action |
|---|---|
| Ctrl+F | Focus product search and select the existing search text |
| Enter in product search | Open the first matching product/variation picker |
| Ctrl+S | Save sale/purchase after normal validations and permissions |
| F6 | Show/hide payment details |

Use the **keyboard icon** in the top bar for a complete in-app guide.
Windows Flutter builds require an actual successful GitHub Actions run; this ZIP
has not been compiled locally, so do not use it on live data before testing.

### Regression scenarios to check after GitHub build
1. All navigation shortcuts work when focus is in blank area or a text field.
2. User lacking Purchases cannot navigate to Purchase Invoices using F4.
3. Ctrl+F focuses POS product search. Ctrl+S does not save an empty cart.
4. F5 in POS requires confirmation before cart reset if unsaved items exist; Cancel preserves cart.
5. Navigating away from a nonempty POS cart and switching POS modes requires confirmation.
6. F1 works on the Dashboard/POS and does not perform any sale.
7. Invoices, returns, split payments, negative stock, ledger, licensing, payroll
   and database reset existing tests continue passing.
