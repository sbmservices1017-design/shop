# ShopDesk Pro v0.6.0 — Integrated Flutter Windows Source

This project preserves the pre-existing inventory/billing/accounts/HR/reporting modules and integrates the user-requested commercial desktop upgrades in one Flutter project and one GitHub Windows build workflow.

## New in v0.6.0

- First application launch: choose **Create New Database** or **Restore Existing Backup**. For an existing ShopDesk SQLite file, this wizard is skipped. Restoration is integrity-checked and performed BEFORE the database is opened.
- New owner registration with shop details, login on subsequent launches. Login and passwords remain local to SQLite.
- 48-hour trial starts on initial owner registration, with a persisted local trial marker so a simple DB replacement cannot reset the trial. Dashboard and top bar show a seconds-level remaining countdown. On expiry the app is replaced by the activation screen, including Machine ID and signed activation token input.
- Signed offline licenses supported by the existing separate private owner generator: 1 month, 1 year, 2 years, lifetime. The client contains only an Ed25519 PUBLIC key.
- Dashboard: refreshes data from SQLite every 5 seconds with metrics, sales vs purchases trend, stock categories, expense categories, paid/unpaid/partial counts, top products, receivables/payables and recent transactions.
- Settings contains: Shop Profile, Users & Permissions, Backup & Restore, License Activation, System Information. Shop logo continues to appear in A4 PDF exports.
- Restore after installation is **staged**, validated and executed before the database opens on the NEXT app launch. An additional rollback copy of the previous database is kept.
- Existing Sales/Purchase POS, dynamic variants, negative stock, payment updates, customer/supplier ledgers, employee/payroll, and filtered PDF/Excel/A4 reports remain in the project.

## Build ONE Windows release with GitHub

1. BACK UP your existing, working `main` branch and ShopDesk SQLite file first.
2. Create a new `shopdesk-pro-v0.6` branch. Do not immediately overwrite your working release.
3. Upload **contents of this ShopDesk folder** to repository root, including hidden `.github/workflows/windows-build.yml`.
4. GitHub **Actions → Build ShopDesk Windows EXE (v0.6.0) → Run workflow**. Ensure analyzer, Flutter tests and Windows build all pass.
5. Download the `ShopDesk-Windows-Release` artifact and extract ALL files together (EXE + DLL + data). Compare against your working version on a COPY of your live DB before production usage.

## Owner private key generator

The owner generator is distributed **SEPARATELY** as `ShopDesk_OWNER_PRIVATE_Key_Generator.zip`. It must NEVER be committed to GitHub, delivered to customers or bundled in the Flutter Windows release. The bundled public key and external generator were checked to correspond.

Owner issues a license using (after installing Python `cryptography`):

```powershell
py generate_license.py MACHINE_ID 1month
py generate_license.py MACHINE_ID 1year
py generate_license.py MACHINE_ID 2year
py generate_license.py MACHINE_ID lifetime
```

Durations use fixed days (30/365/730), not calendar-month subscription billing.

## Critical limitations and verification state

- Source package creation, Dart-bracket structural scan, SQLite DDL/integrity tests and public/private key correspondence were checked in the preparation environment.
- **Flutter / Dart analyzer, actual Windows compilation, printing, first-launch wizard on Windows, new license timing UI and complete backup/restore integration tests were NOT executed here** because Flutter SDK / Windows build environment was unavailable. The GitHub Action MUST pass before distributing the EXE.
- Fully offline licensing is not tamper-proof against administrators able to modify application code, local time or disk state. The local trial marker is an additional guard, NOT invulnerable DRM.
- Per-module user permissions are primarily UI/enforced workflows; the local database is not encrypted and every direct DB access path has not undergone a production security audit.
- Profit/COGS, stock costing and some financial closing workflows from earlier versions remain out of production-certification scope. Never use unverified accounting reports to make financial decisions without reconciliation.
- A specific dashboard reference image was mentioned, but was not available in the provided source material. The dashboard adopts a professional navy/blue analytics layout; exact image/pixel matching requires that image.

## Starting an existing installation

Existing database path and product/account structures are preserved. If `shopdesk.sqlite` already exists in Windows application support, users see the login screen, NOT the first-launch wizard. If the database predates users, the app asks to create its first owner without deleting business data. Back up the original before migrating.

## Upgrade / acceptance scenarios

See `docs/UPGRADE_ACCEPTANCE_V0_6.md` for the feature matrix and hands-on test cases.
