# ShopDesk Pro v0.6: Requirements & Acceptance Checklist

## Requested change → Integrated location

| Requirement | Code / screen | Release status |
|---|---|---|
| First start Create / Restore | `lib/boot_setup.dart` | Implemented, Windows UI test pending |
| Skip setup on subsequent starts | `ShopDeskBootstrap` file detection | Implemented, Windows UI test pending |
| Owner registration and subsequent login | `CommercialGate` / `_CredentialScreen` | Implemented, login regression test present |
| Shop name/phone/address capture | Owner registration, Shop Profile in Settings | Implemented |
| Dynamic 48-hour trial, seconds countdown | `CommercialCore`, `license_widgets.dart` | Implemented, time-machine test pending |
| Trial expiry locks work | `CommercialGate` checks license before application | Implemented, real clock test pending |
| Machine ID on activation screen | `ActivationScreen` / `CommercialCore` | Implemented |
| Invalid activation rejected | Ed25519 public-key verifier | Implemented, invalid-token test present |
| One-month, one-year, two-year, lifetime activation | External owner license generator | Implemented, verify on actual Windows device |
| Enhanced dashboard, more graphs | `advanced_dashboard.dart` | Implemented, visual Windows test pending |
| Sales/Purchase POS with product variations | Existing `modern_pos.dart` | Retained |
| Settings unified sequence | `settings_hub.dart` | Implemented |
| Users and per-module permissions | `UserManagementScreen` | Retained; backend hardening pending |
| Shop logo in A4 bills/reports | ShopProfileScreen & reporting.dart | Retained |
| Backup + staged restore after initial setup | BackupSettings + ShopDatabaseSetup | Implemented, restore drill pending |
| Stock, products, sales, purchase, expenses, employees, accounts, reporting | Existing ShopDesk modules | Retained; business acceptance pending |

## Acceptance test scripts (must be carried out on Windows with a TEST database)

1. On a PC without a ShopDesk DB, launch EXE; verify two first-launch choices.
2. Create a new database. Register a new owner and shop name. Verify it starts 48-hour trial ONCE.
3. Shut down and reopen. Verify startup goes to LOGIN, not to first-launch setup.
4. Verify dashboard trial countdown decreases live every second and charts update after a new sale/purchase within 5 seconds.
5. Post a negative-stock sale, then post a purchase to recover stock; verify ledger and stock movement.
6. Create users, grant a Sales-only role and verify non-admin cannot access admin Settings, Purchases and other modules.
7. Try a random/incorrect/wrong-machine license token; confirm activation is refused.
8. Generate a signed key on owner's private system; confirm matching machine activates, displays status and does not expire immediately.
9. Set up an already-expired trial in TEST DATA; confirm normal shop screens are blocked and only activation is offered.
10. Create a Shop Profile/logo and verify PDF and A4 print headers include it.
11. Take a SQLite backup with Settings, validate its file and restore via first-launch wizard on a separate clean installation; ensure users, stock, invoices and ledger match.
12. Stage a restore in Settings; close app, restart, confirm recovery copy exists and restored database loads.
13. Confirm existing pre-v0.6 database opens without a first-launch wizard and that all legacy data remains.
14. Verify PDF/Excel filtered reports and receipt/status changes after partial and final payments.
15. Verify GitHub workflow: analyze, full test suite, Windows release, entire EXE/DLL/data artifact.

### Do not claim production complete until

- Flutter static analysis has no **errors** and tests pass.
- EXE launches and navigation works on supported Windows machines.
- An end-to-end backup/restore drill, physical printer test, license/clock expiry test and financial data reconciliation pass.
- Existing inventory and ledger regression comparisons against the last working version are documented.

**Owner private signing PEM does not belong in a GitHub repository or client build.**
