# Functional Test Evidence — ParchiPocket Prototype

**Test date:** 27 October 2026  
**Test type:** Automated browser tests against the local interactive prototype  
**Automation:** Playwright with Chromium  
**Result:** 7 passed, 0 failed

> Scope note: These results apply to the static browser prototype used to validate the core billing workflow. They do not establish that the Flutter Android application passed Flutter tests, was built as an APK, or was tested on an Android device.

| # | Test | Expected result | Actual result | Status |
|---:|---|---|---|---|
| 1 | Empty quick bill validation | Validation message appears; no bill is saved | Error visible; saved bills = 0 | PASS |
| 2 | Amount-only quick bill | ₹250.00 receipt with an ID; one bill saved | ₹250.00 shown; receipt ID generated; one bill saved | PASS |
| 3 | Itemised bill arithmetic | 2 × ₹10 + 1 × ₹20 = ₹40.00 | Form and receipt both showed ₹40.00; two bills saved in total | PASS |
| 4 | History search | Search finds the Test Customer record | One matching row; customer visible | PASS |
| 5 | Expense separation | Expense appears separately and does not change sales count | One expense; two bills; expense note visible | PASS |
| 6 | Saved-state reload | Two bills and one expense rehydrate from saved browser storage | Two bills and one expense restored | PASS |
| 7 | CSV export | Downloaded CSV exists and is non-empty | File created; 228 bytes | PASS |

## Test data

Only synthetic test data was used: “Test Customer”, Tea, Biscuits, and a “QA travel sample” expense. These are test fixtures, not real customer transactions.

## Evidence files

The local test run generated screenshots for the quick-bill receipt, itemised receipt, history search, and dashboard. Keep these with the course submission package if the instructor requests screenshots. Do not present mock-up screen previews as screenshots from a compiled Android APK.

## Android verification still required

Run these commands from mobile/parchipocket_flutter/ in a configured Flutter/Android environment:

    flutter pub get
    flutter test --reporter compact
    flutter analyze
    flutter devices
    flutter run

Record the real command output and device/emulator used. Do not mark these checks as passed before running them.
