---
name: pp-audit
description: >-
  Comprehensive, read-only health and security audit for ParchiPocket. Discovers code quality, bugs, authentication/session logic, Firestore security rules and data ownership, user data privacy, hardcoded secrets, Android permissions, dependencies, voice parsing, dashboard calculations, performance, and test/build health. Strictly read-only; never modifies files, commits, pushes, deploys, or deletes data.
---

# ParchiPocket Health & Security Audit (`/pp-audit`)

This skill defines a comprehensive, strictly **READ-ONLY** audit procedure for the ParchiPocket Flutter Android application and its Firebase backend.

> [!CAUTION]
> **STRICT AUDIT RULE**: This skill is strictly read-only. Never modify source code, never modify tests, never commit, never push, never deploy production rules, and never delete or alter user records.

---

## 1. Scope of Inspection

The audit evaluates the repository across 14 vital dimensions:

1. **Flutter and Dart Code Quality**:
   - Static analysis warnings, linter conformance, strict-casts, unhandled exceptions, and dead code.
   - Command: `flutter analyze` inside `mobile/parchipocket_flutter`.
2. **Bugs, Logic Errors & Edge Cases**:
   - Negative, zero, or non-finite financial amounts (NaN, Infinity).
   - Numeric overflow, rounding errors, and nullability edge cases in state transitions.
   - Idempotency and duplicate submissions during network retries.
3. **Authentication, Login & Logout**:
   - Phone/OTP verification workflows and state transitions in `auth_screens.dart`.
   - Complete state teardown on logout to prevent credential/session retention or cross-session leakage (`app_state.dart`).
   - Clean separation between offline demo sessions and authenticated cloud sessions.
4. **Firestore Security Rules & Data Ownership**:
   - Path-level security in `firestore.rules` verifying `isOwner(userId)` gating.
   - Owner-only access on `/users/{userId}/householdExpenses/{expenseId}`, `/bills`, `/expenses`, and `/savedShops`.
   - Immutable collections: Ensure update and delete operations on immutable financial records remain rejected (`allow update, delete: if false;`).
5. **Unauthorized Reads & Writes**:
   - Verify non-owners cannot read, write, update, or enumerate other users' documents.
   - Verify unauthenticated requests are strictly rejected (`403 Forbidden`).
   - Validate that collection enumeration (`list`) is denied for global collections where inappropriate.
6. **User Data Privacy & Sensitive Information Exposure**:
   - Verify phone numbers, payment records, and personal spending entries are not exposed via client logs, debug prints, or unauthenticated queries.
7. **Hardcoded Secrets & Credentials**:
   - Inspect codebase for embedded private keys, service account JSON files, and unmasked credentials.
   - Verify public Firebase client identifiers (`google-services.json`, `firebase_options.dart`) are restricted via App Check / backend rules.
8. **Android Permissions & Configuration**:
   - Inspect `AndroidManifest.xml` for least privilege (`RECORD_AUDIO`, `INTERNET`, queries declarations).
   - Review debug vs release configuration and network security configs.
9. **Dependency Vulnerabilities & Outdated Packages**:
   - Audit `pubspec.yaml` and `pubspec.lock` using `flutter pub outdated`.
   - Check npm packages (`package.json`) if applicable.
10. **Voice Recognition & Natural Language Expense Parsing**:
    - Parser logic in `household_expense_parser.dart` handling Hinglish, price-first phrasing, Indian numeric comma grouping (`1,500`), and quantity vs. price distinction (e.g., `2 kg` vs `₹2`).
    - Review-before-save enforcement: Verify voice inputs cannot be saved until recognition is finalized and reviewed by the user.
11. **Dashboard Calculations & Expense History**:
    - Aggregation accuracy for today and monthly totals in `CustomerHomeScreen`.
    - Date and timezone boundary handling.
12. **Performance & Firebase Read Optimization**:
    - Prevent unbounded reads, missing document limits, redundant stream rebuilds, and memory leaks.
13. **Unit, Widget & Integration Tests**:
    - Execution of all unit and widget tests: `flutter test --reporter compact`.
    - Check for disabled, skipped, or mock-evading tests.
14. **Debug & Release APK Build Health**:
    - Verify Android Gradle build configuration, target SDK, and compile SDK settings.

---

## 2. Environment Setup & Local Verification Commands

### Java Environment (Windows)
Firebase emulators require Java. On Windows machines where Java is not on the global system PATH, use Android Studio's bundled JBR:

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
```

### Isolated Firestore Security Rules Test
Execute the test harness against an **isolated demo emulator project** only. Never run against production:

```powershell
# From C:\dev\parchipocket
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
npx --yes firebase-tools@latest emulators:exec --only auth,firestore --project demo-parchipocket-phase4 "node test_rules.js"
```

### Flutter Static Analysis & Unit Tests
```powershell
cd mobile/parchipocket_flutter
flutter analyze
flutter test --reporter compact
```

---

## 3. Severity Classification Matrix

Every finding must be classified into one of the following four severity tiers:

* **Critical**: Direct security vulnerability, unauthorized access to user financial data, bypass of Firestore security rules, hardcoded production secrets, or complete app-crashing regression.
* **High**: Authentication race condition, state desynchronization between cloud and demo mode, incorrect financial calculations, or voice parser failure mischarging an amount.
* **Medium**: Missing input validation on edge cases, suboptimal Firestore read patterns, outdated non-vulnerable dependency, or minor UI/state inconsistency.
* **Low**: Code style violation, dead code, missing docstrings, minor formatting inconsistencies, or non-blocking deprecation warnings.

---

## 4. Audit Report Structure

Generate the audit report using this standardized markdown structure:

```markdown
# ParchiPocket Health & Security Audit Report

## Executive Summary
- Overall Health Score: [Pass / Conditional Pass / Fail]
- Total Findings: [Total count broken down by Critical, High, Medium, Low]

## Summary of Completed vs Incomplete Checks
- [x] Flutter static analysis (`flutter analyze`)
- [x] Flutter unit and widget tests (`flutter test`)
- [x] Firestore security rules emulator test (`test_rules.js` via emulator)
- [ ] [Any check that could not run, with reason]

## Findings by Severity

### [Severity: Critical | High | Medium | Low] - <Title>
- **Category**: [e.g., Firestore Security / State Race / Input Validation]
- **Affected Files**: [`file.dart:line`](file:///...)
- **Evidence**: [Code snippet or command output]
- **Reproduction Steps**: [Step-by-step description]
- **Impact Analysis**: [Potential risk to user data, privacy, or stability]
- **Recommended Remediation**: [Targeted, minimal fix recommendation]

## Next Steps
- Actionable prioritized checklist for `/pp-fix`.
```
