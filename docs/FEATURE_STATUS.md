# Feature Status

Status describes the starter archive currently stored in this repository, not a claim of production readiness.

| Area | Current status | Notes |
|---|---|---|
| Welcome and onboarding | Demo implemented | UI flow only |
| Phone and OTP login | Mocked | Demo code is 123456; no SMS validation |
| Google login | Preview/demo | No live OAuth connection |
| Account roles | Demo implemented | Customer, Shop Owner, Street Vendor |
| Customer home and bill history | Demo implemented | Sample in-memory records |
| Bill detail | Demo implemented | Sample records |
| QR scanning | Placeholder | Camera/scan workflow not integrated |
| Spending insights | Demo view | Sample data and summaries |
| Nearby / saved shops | Demo view | No production location/discovery service |
| Shop-owner dashboard | Demo implemented | Local sample data |
| Create bill / total calculations | Frontend demo | Validate with tests before real use |
| Expenses | Demo implemented | In-memory records |
| Udhaar / settlement | Demo implemented | In-memory records |
| Sales reports / export | Preview | No production report pipeline |
| Customer directory | Demo view | No secure cloud sync |
| Thermal printer settings | Preview | No confirmed Bluetooth printer integration |
| Street-vendor quick billing | Demo implemented | In-memory records |
| Persistent database | Not implemented | State resets on restart |
| Real account security / authorisation | Not implemented | Required before production |
| QR generation and secure receipt links | Planned | Access policy and expiry required |
| PDF generation/share | Preview/planned | End-to-end export not connected |
| Push notifications | Not implemented | No push service connected |
| Offline sync / conflict resolution | Not implemented | Needs explicit design |
| Automated tests | Starter tests included | Must run and extend tests against requirements |

## Release gate

Do not call the app production-ready until real authentication, persistence, access-control rules, error handling, data recovery, privacy review, QR/link access tests, and critical business-flow tests have been implemented and verified.
