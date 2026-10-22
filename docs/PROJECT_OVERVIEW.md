# ParchiPocket: Project Overview

**Project owner:** Rabit Mansuri (@rabit001)  
**Initial target:** Android mobile application  
**Client technology:** Flutter and Dart  
**Status:** Frontend prototype / starter

## 1. Problem area

Small vendors and local shops often handle small, frequent transactions where handwritten slips and informal records can be difficult to search, total, or share later. Customers may also lack a single place to review purchases. ParchiPocket explores a simple digital record workflow for sellers and customers.

This is the project's working problem statement, not a claim that a completed local user study has validated every assumption.

## 2. Vision

Create an easy-to-use mobile application that supports everyday billing and record keeping for three roles:
- **Customer:** review receipts and purchase history.
- **Shop Owner:** create itemised bills, track sales, maintain expense and udhaar records.
- **Street Vendor:** create quick bills with minimal steps.

## 3. Product principles

- Make frequent billing actions quick.
- Keep sales, expenses, and udhaar distinct.
- Use clear totals and readable receipt details.
- Minimise the personal information collected.
- Let customers save or link receipts only through a clear, consent-aware flow.
- Label prototype-only screens honestly until live services are implemented.

## 4. Current starter

The current archive is a Flutter UI starter with role-specific screens, sample data, navigation, reusable widgets, and demo interactions. It is useful for UI review and development planning, but it is not a production billing service.

## 5. Current limitations

Authentication is mocked, the demo OTP is `123456`, and records live in in-memory demo state that resets when the app restarts. QR scanning, cloud sync, real Google/phone authentication, receipt PDF/share output, and thermal printing are not connected end-to-end. Do not use the prototype as a real financial ledger.

## 6. Planned releases

1. Validate navigation and responsive layouts on emulator and physical Android devices.
2. Finalise requirements, data model, threat/privacy review, and role-based access rules.
3. Implement real authentication and persistent storage.
4. Implement reliable receipts, QR/link flow, PDF export, and supported printer integration.
5. Add automated tests, recovery/offline behaviour, error handling, and a limited pilot checklist.
