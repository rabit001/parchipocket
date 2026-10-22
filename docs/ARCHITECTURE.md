# Architecture Notes

This document separates the **current prototype** from the **proposed production architecture**. Proposed components are not implemented merely because they appear here.

## Current prototype

```text
Flutter UI (Dart)
  ├── Authentication / onboarding screens (demo)
  ├── Customer screens
  ├── Shop-owner screens
  ├── Street-vendor screens
  ├── Shared screens and reusable UI widgets
  └── AppState with local in-memory sample records
```

The current app entry point routes between screens in `lib/main.dart`. Shared demo state is in `lib/app_state.dart`, styling is in `lib/theme.dart`, and reusable widgets are in `lib/widgets/ui.dart`. Role-specific UI source files are in `lib/screens/`.

## Proposed production architecture

```text
Android Flutter Client
   ├── Authentication and profile
   ├── Billing / receipt domain logic
   ├── Customer purchase history
   ├── Seller sales / expense / udhaar
   └── Receipt presentation and export
              │ authenticated requests
              ▼
Backend / managed services (to be selected)
   ├── Authentication
   ├── Authorised API or server-side rules
   ├── Persistent database
   └── Optional storage for generated receipts
              │
              ├── QR or share-link receipt access
              ├── PDF receipt output
              └── Compatible thermal printer adapter
```

## Data concepts to design

- **User:** identifier, role, display name, optional contact data, consent and settings.
- **Shop:** owner identifier, display name, optional address/contact and configuration.
- **Bill:** unique ID, shop/seller ID, timestamp, item lines or quick-bill amount, total, payment label and status.
- **Bill item:** description, quantity, unit price and calculated line total.
- **Expense:** amount, category, timestamp, note and shop/seller ID.
- **Udhaar entry:** amount, customer reference where appropriate, created/settled timestamps and settlement state.
- **Customer receipt link:** minimal tokenised reference with expiry/access policy if link sharing is implemented.

## Security and privacy rules to settle before production

1. Sellers can read and change only their authorised shop records.
2. Customers can access only receipts explicitly shared or linked to their verified account.
3. Phone linking must be optional and consent-aware.
4. Never store UPI PINs, bank passwords, card credentials, or authentication secrets in app records.
5. Validate monetary values and quantities on the client and again at the trusted backend.
6. Avoid exposing personal information in public QR payloads or long-lived share URLs.
7. Plan deletion, backup, recovery, logging, and access-revocation behaviour.

## Integration decisions still open

Choose the backend and authentication provider only after reviewing cost, security rules, data export/recovery, expected traffic, and maintenance needs. Printer integration must be tested against actual target hardware. QR, PDF and cloud sync features must be treated as planned until code and tests verify them.
