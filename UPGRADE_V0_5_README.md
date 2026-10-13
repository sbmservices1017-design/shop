# ShopDesk Pro upgrade (v0.5.0) — integrated DEVELOPMENT source

Original base: ShopDesk Flutter v0.4.3 from the prior conversation. The public repository https://github.com/sbmservices1017-design/shop contains a matching v0.4.3 source layout. A clone of the exact latest remote commit was unavailable in this workspace; compare the source against your live repository before replacing files.

## Included code changes

- `lib/commercial_core.dart`: owner registration, salted PBKDF2 passwords, sign-in, user CRUD/deactivation, per-module permissions, machine identifier, 48h trial, clock rollback check and Ed25519 signed offline activation (1 month = 30 days; 1 year = 365 days; 2 years = 730 days; lifetime has no expiration).
- `lib/commercial_ui.dart`: owner registration/login, activation, employee user management and permissions, shop branding with stored logo.
- `lib/license_public.dart`: PUBLIC verification key only. PRIVATE key is provided in a separate owner-only bundle.
- `lib/modern_pos.dart`: sales and purchase POS, SKU/attribute search, category chips, cart/quantities, manual rate, partial/full payment, negative-stock posting, A4 print, invoice history/reprint, legacy invoice correction and void actions.
- `lib/advanced_dashboard.dart`: additional live sales, purchases, expenses, receivables, payables, inventory alerts, transactions and sales trend.
- `lib/reporting.dart`: shop name, address, phone and optional logo on PDF/A4 report headers.
- `lib/store.dart` and `lib/extensions.dart`: new `receipt_allocations` table; later customer/supplier payments apply against oldest outstanding invoices and update invoice `paid`; receipt reversals restore the previous balance. Existing stock accounting/posting paths remain intact.
- `test/commercial_test.dart` and additional regression tests for invoice payment status.
- Existing modules are retained; added screens are part of the SAME application.

## Install/build from GitHub

1. BACK UP your existing SQLite database and the working GitHub repository first.
2. Make a new branch `shopdesk-pro-v0.5` in the repository. Do not replace your working `main` branch before build/testing.
3. Copy the contents of THIS project folder into the new branch's repository root. The folder `.github/workflows` must be included.
4. GitHub **Actions > Build ShopDesk Windows EXE (v0.5.0)**. Wait for analyzer, tests and Windows build.
5. If Actions succeeds, download the `ShopDesk-Windows-Release` artifact. Extract the WHOLE bundle; do not run the EXE without its DLL/data directory.
6. Test in a fresh copy of the SQLite database, then run the full shop acceptance checklist, then and only then release to users.

### Safeguard existing live data

ShopDesk stores data in the Windows application-support directory, not in the GitHub repository. The migration adds tables to an existing SQLite database; it must not delete your invoices, products or ledgers. Nonetheless, make an offline database backup before first launch with this upgrade. Test with a copy first.

### Owner key generator

Download the **separate** `ShopDesk_OWNER_PRIVATE_Key_Generator.zip` file sent in chat. NEVER upload its private PEM or the owner's ZIP to a public GitHub repository or client PC. Keep an offline backup of the private signing key: losing it prevents you from generating new compatible keys; leaking it lets others issue keys.

Generate keys on the owner's computer:

```powershell
py -m pip install cryptography
py generate_license.py DEVICE_CODE 1month
py generate_license.py DEVICE_CODE 1year
py generate_license.py DEVICE_CODE 2year
py generate_license.py DEVICE_CODE lifetime
```

The **device code** is displayed on the client's activation screen. They paste the signed activation key you produce. Only the PUBLIC verification key is embedded in ShopDesk's app source.

## Important testing/feature limitations

This is an integrated **development candidate**, NOT a confirmed production-ready Flutter Windows release.

- Flutter SDK, Dart analyzer, regression tests, Windows release build, printer hardware and live shop testing could **not be run** in the current environment. Python structural checks, SQLite DDL/integrity checks and cryptographic key signing/verification were performed.
- View and basic create/edit/delete checks in the UI are wired, but full backend authorization for *every* direct store/database mutation is not yet enforced. Permission controls should not be treated as tamper-resistant security against local users; the SQLite DB is local and unencrypted.
- License keys are digitally signed and machine-bound, but fully offline apps remain vulnerable to machine clock, system file and database tampering by privileged local users. Full enforcement requires OS hardening and device-specific Windows acceptance tests.
- Payment status allocation is implemented for subsequent customer/supplier receipts. Partial returns, overpayments and invoice corrections need additional acceptance tests for complex real-world scenarios.
- Inventory costing/COGS, multi-unit roll/meter conversions, payroll correction/closing, accounting close policy and production-grade restore are NOT completed by this upgrade.
- The separate owner generator uses **calendar-independent fixed day durations** (30/365/730), not billing-date calendar months.

Do not use with real money until GitHub build passes and inventory, payments, payroll and accounting have been reviewed with the shop's test data.
