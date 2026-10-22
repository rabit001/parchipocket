# ParchiPocket Flutter Frontend Starter

A Flutter Android starter based on the ParchiPocket Figma prototype. It focuses on mobile UI and local demo interactions for customers, shop owners, and street vendors.

## Included

- Welcome, mocked Google sign-in flow, phone number and demo OTP flow
- Role selection and separate customer/shop-owner/street-vendor setup
- Customer home, searchable bills, itemised receipt, manual bill-code lookup, spending insights, nearby shops, saved shops, profile and edit profile
- Shop-owner dashboard, bill creation with item validation and totals, local receipt creation, bill history, expenses, udhaar settlement confirmation, sales report preview, customer directory and printer preview
- Street-vendor quick billing, multi-item flow, receipt, sales history and profile
- Notifications preferences, language setting, FAQs, support submission preview, receipt-sharing preview, privacy screen, logout confirmation and account-deletion review
- Reusable UI widgets, theme colours, local in-memory demo state and sample records

## Important limitations

This is **frontend starter code**, not a production-ready application. Login is mocked, the OTP is the demo value `123456`, data resets when the app restarts, QR scanning is a placeholder, and share/PDF/printer screens are previews. There is no cloud database, real customer account linking, SMS, Google OAuth, push notification service or Bluetooth printing connected. Demo data must not be used as an actual business ledger.

## Run on your computer

1. Install the Flutter SDK and Android Studio, including an Android SDK and emulator or connect an Android phone with USB debugging enabled.
2. Extract this project folder on your Windows computer.
3. Open PowerShell in the extracted `parchipocket_flutter` directory.
4. Run `flutter doctor` and fix any Android toolchain issues it reports.
5. Generate the native Android platform folder and fetch packages by running:

   ```powershell
   .\setup_android.ps1
   ```

6. Start an Android emulator or connect a phone with USB debugging enabled, then run:

   ```powershell
   flutter run
   ```

The setup script uses the Flutter SDK on your computer to create the Android Gradle/Kotlin wrapper. It does not overwrite the Dart UI source files.

## Build an Android release bundle later

After installing the required Android build tools and completing app configuration/signing:

```bash
flutter build appbundle --release
```

The generated AAB is only a build artifact. Play Store publishing still requires production authentication, backend and data-protection decisions, testing, signing, store listing assets, and compliance with current Play Console requirements.

## Next development stage

1. Review the Flutter UI against the Figma screens on a phone-sized viewport.
2. Decide the backend and data model for users, shops, receipts, item lines, expenses, udhaar, saved shops and consented customer links.
3. Add actual Google/phone authentication and verified customer bill ownership.
4. Add QR generation/scanning, PDF receipt export and supported thermal-printer integration.
5. Test error, offline, security, accessibility and data recovery behaviour before release.

## Source layout

- `lib/main.dart`: app entry and page router
- `lib/app_state.dart`: demo models and local in-memory state
- `lib/theme.dart`: app theme tokens
- `lib/widgets/ui.dart`: reusable buttons, cards, fields, transaction rows and layout widgets
- `lib/screens/`: onboarding, customer, shop-owner, street-vendor and shared screens
