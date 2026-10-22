# Development Roadmap

This roadmap tracks proposed work. Items below are not claimed complete unless the repository code and tests demonstrate that they are.

## Stage 0: Project baseline
- [x] Flutter starter source created.
- [x] Customer, Shop Owner, and Street Vendor demo flows.
- [x] Initial README and development documentation.
- [ ] Confirm the checked-in source archive runs on another clean Windows environment.
- [ ] Run and document the starter tests.

## Stage 1: Requirements and design
- [ ] Review each screen on phone-sized emulator and physical device.
- [ ] Write acceptance criteria for bill creation, totals, payments, expense separation, and udhaar settlement.
- [ ] Define minimum customer data and receipt-link consent.
- [ ] Draw final component and data-flow diagrams.

## Stage 2: Persistence and authentication
- [ ] Select authentication and backend based on security, cost, and maintenance.
- [ ] Define user, shop, bill, item, expense, udhaar, and receipt-link schemas.
- [ ] Implement real authentication and sign-out.
- [ ] Enforce role/owner access on the trusted backend.
- [ ] Add data migration, deletion, and backup/recovery plans.

## Stage 3: Core billing
- [ ] Add validated bill creation and unique identifiers.
- [ ] Persist bills and retrieve history.
- [ ] Keep sales totals separate from expense and udhaar accounting.
- [ ] Add duplicate-submit prevention and useful error messages.

## Stage 4: Receipts and hardware
- [ ] Implement QR generation and scanning with safe token/link access.
- [ ] Implement PDF receipt export and sharing.
- [ ] Select target thermal printer models and test compatibility.
- [ ] Handle permission denial, connection failures, and print retry.

## Stage 5: Quality and pilot
- [ ] Unit tests for billing and totals.
- [ ] Workflow and negative-input tests.
- [ ] Access-control and privacy tests.
- [ ] Offline, recovery, accessibility, and performance checks.
- [ ] Pilot with consenting users and a documented issue log.
