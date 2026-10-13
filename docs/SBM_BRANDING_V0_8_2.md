# ShopDesk Pro v0.8.2 — SBM Services Branding

Changes limited to branding/presentation: no transaction, stock, salary or licensing engine modifications.

- Registration, login, first-run database setup and license activation use split desktop layout: original SBM Services logo on left; functional form on right.
- The SBM logo is shipped as a locally bundled, cropped transparent PNG and does not require network access.
- Every primary authenticated module renders the same bottom footer from `SbmFooter` in `lib/brand_identity.dart`.
- Footer: “All Rights Reserved © SBM Services”, “Support: 03060730653”, “sbmservices@gmail.com”.
- All branding strings are centralized in `SbmIdentity`.
- Compact windows stack the logo above the form to avoid overflow.
- Source is *not* a verified Windows EXE. Run Flutter analyze, tests and GitHub Actions before deployment.

## Suggested acceptance checks
1. At 1366×768, login: SBM logo left, form right, footer fully readable.
2. At 1024×768 and 800×650, no horizontal overflow; form scrolls if required.
3. First launch, registration, activation use the same brand layout.
4. Sign in and open each module; copyright/phone/email remain visible at bottom.
5. POS, invoice corrections, payroll advances and license activation still work normally.
6. Confirm no private PEM/license generator was bundled with this client project.
