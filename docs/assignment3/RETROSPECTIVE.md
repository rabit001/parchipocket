# Assignment 3 — Retrospective

## What went well

- The core bill-creation path was testable with both amount-only and itemised bills.
- The prototype produced receipt previews and a receipt identifier after saving.
- Bill history could be searched using a customer name.
- Expenses were recorded separately from sales.
- CSV export created a non-empty file in the automated browser test.

## Issues and limitations

- The static prototype stores data in browser-local storage; it does not sync between devices or provide a cloud backup.
- A browser prototype is useful for validating the basic workflow, but it does not prove Android installation quality or mobile-device performance.
- The Android build and Flutter test suite must be run in a configured Flutter/Android environment before claiming that the native app passed.
- Authentication, payment processing, automatic UPI verification, tax filing, full accounting, inventory, and guaranteed printer support are outside the current prototype scope.
- Local vendor/customer demand has not been validated through interviews in the evidence currently recorded for this assignment.

## Prioritised next steps

1. Run and record Flutter tests and static analysis.
2. Test the main flows on an Android emulator and at least one physical device if available.
3. Conduct short usability sessions with intended users and record genuine feedback with consent.
4. Improve the most frequently reported usability issue.
5. Verify receipt sharing, security, backup, and data-retention behaviour before any real financial data is used.
6. Record the demo video after the build and test state is accurately represented.

## Before / after evidence

The prepared mobile screen previews and monochrome design assets illustrate the intended interface. They are design previews, not proof of a before/after usability study. Add actual screenshots and feedback-based changes after collecting user evidence.
