# ParchiPocket

**Owner and project author:** Rabit Mansuri (@rabit001)  
**Project type:** Mobile-first digital billing and transaction-record application  
**Current client:** Flutter / Dart for Android

ParchiPocket is being developed to help customers, shop owners, and street vendors create and review digital bill records. It aims to simplify everyday billing for small businesses without forcing every seller to use a complicated accounting system.

> **Project status:** Frontend starter/prototype. This repository documents the current demo and its planned development. It is not yet a production-ready billing or accounting service.

## Product goals

- Let customers review purchase records and receipts.
- Let shop owners create itemised bills, view bill history, track expenses, and manage udhaar records.
- Offer street vendors a faster amount-only or simple itemised billing flow.
- Keep sales, expenses, and credit/udhaar records separate.
- Plan receipt sharing through QR/link, PDF output, and supported thermal printers.
- Provide readable, role-specific screens and simple navigation.

## Current prototype features

### Shared / onboarding
- Splash and welcome screens.
- Demo sign-in and phone/OTP flow.
- Role selection: Customer, Shop Owner, Street Vendor.
- Profile and settings screens.
- Help, FAQ, support, privacy, and notification preference screens.

### Customer
- Home dashboard and recent purchases.
- Bills/history and bill detail.
- QR scanning placeholder and manual bill-code flow.
- Spending insights.
- Nearby and saved shops.
- Profile and edit profile.

### Shop owner
- Dashboard and daily sales preview.
- Create itemised bills and calculate totals.
- Receipt preview and bill history.
- Expenses, udhaar, and settlement confirmation.
- Sales report/export preview.
- Customer directory and printer settings/test preview.

### Street vendor
- Quick billing and multi-item billing.
- Receipt preview and sales history.
- Vendor profile.

## Technology

- Flutter and Dart.
- Android Studio and Android SDK for Android development.
- Local in-memory demo state for the current starter.

## Important limitations

The current starter is a **front-end demo**, not a production release:

- Authentication is mocked; the demo OTP is `123456`.
- Data is held in local in-memory state and resets when the app restarts.
- Google sign-in, real SMS OTP, a cloud database, secure customer-account linking, and push notifications are not connected.
- QR scanning is a placeholder.
- PDF, receipt-sharing, and thermal-printer interfaces are previews rather than completed integrations.
- Do not use the demo data as an actual business ledger.

## Repository layout

```text
.
├── README.md
├── .gitignore
├── docs/
│   ├── PROJECT_OVERVIEW.md
│   ├── ARCHITECTURE.md
│   ├── FEATURE_STATUS.md
│   └── SETUP_GUIDE.md
└── releases/
    └── ParchiPocket_Flutter_Frontend_Starter.zip
```

The ZIP in `releases/` contains the current Flutter starter source snapshot. Extract it before opening the project in Android Studio. The documentation folders describe the plan and current limitations; they do not imply that planned services are already implemented.

## Run on Windows

1. Install the Flutter SDK and Android Studio, including the Android SDK and either an emulator or a USB-debugging-enabled Android device.
2. Extract `releases/ParchiPocket_Flutter_Frontend_Starter.zip`.
3. Open the extracted `parchipocket_flutter` folder in Android Studio.
4. Open a terminal at that project root and run:

   ```powershell
   flutter doctor
   flutter pub get
   ```

5. If the extracted project does not contain its generated `android/` folder, run:

   ```powershell
   .\setup_android.ps1
   ```

6. Start an emulator or connect an Android device, then run:

   ```powershell
   flutter devices
   flutter run
   ```

Read [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md) for the longer checklist.

## Planned development stages

1. Review and test the current UI and navigation on an emulator and a real phone.
2. Define the backend, data model, and user/role access rules.
3. Add real authentication and safe customer/seller account linking.
4. Persist bills, item rows, expenses, and udhaar records in a backend.
5. Implement verified receipt sharing, QR generation/scanning, PDF export, and tested printer integration.
6. Add unit, workflow, error-state, privacy, and offline tests before any pilot.

## Ownership

This project is maintained under **Rabit Mansuri (@rabit001)**. New code, integrations, and documentation should be reviewed and committed under the project owner's GitHub account.
