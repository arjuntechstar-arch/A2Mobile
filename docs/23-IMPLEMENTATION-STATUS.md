# Implementation status

This supersedes the historical gap review and phase snapshots. Source implementation does not imply production deployment or live-provider acceptance is complete.

| Documentation | Current implementation |
| --- | --- |
| 00–02 Product/architecture | Flutter customer app, React staff portal, FastAPI, transactional MongoDB and scheduled worker. |
| 03 Database | Unique business/idempotency indexes, verification expiry, immutable versions, encrypted profiles, receipts and operational records. |
| 04 Mobile | Registration/verification, sessions/reset, five tabs, profile/nominee, KYC, catalog, calendar, checkout, receipts, notifications, support, refunds/redemption. |
| 05 Admin | Documented navigation/KPIs, paginated records, scheme publication, KYC review, account/role changes, support, stores, content and configuration status. |
| 06 Rules | Joining windows, calendar/due dates, grace, advance/late contributions, deductions, maturity and redemption validity; accepted snapshots. |
| 07 Payments | Real Razorpay adapters, signatures, authoritative fetch, atomic credit/receipt/completion, recovery and reconciliation. |
| 08 KYC | Cashfree PAN and consent-based DigiLocker PAN matching; masked retention, no synthetic approval. |
| 09 API | Authentication, granular permissions, validation, DTO projection, bounded pagination and canonical webhook. |
| 10 Security | Password/challenge hashing, throttling, rotating/revocable sessions, RBAC, secure mobile storage, encryption and mutation audit metadata. |
| 11 Notifications/support | Persistent inbox, device registration/removal, FCM adapters, reminders and support conversations. |
| 12 Redemption/refunds | Fresh code/invoice/store checks, reserved eligibility, transactional redemption, approval and idempotent gateway refunds. |
| 13 Reports | Day/month/scheme/customer collections, benefit liability, operational views and CSV. Contribution receipts remain separate from product invoices. |
| 14 Tests | Real database workflow tests, provider fixtures, admin auth/export tests, Flutter session/navigation tests and backup round trip. |
| 15–17 Delivery | Containers, local Compose, CI checks, setup/testing/restore guide. External acceptance is environment-dependent. |
| 18–21 Phase records | Historical; use this status and the testing guide for current behavior. |

Local checks: backend **38 passed** (one upstream deprecation warning), admin **3 passed** plus type check/build, Flutter **6 passed**, Flutter analysis **no issues**, and Flutter browser release build **passed**. The normal JavaScript web build is used; the secure-storage dependency does not currently support the optional WebAssembly build.

The updated API and scheduled worker were started locally. Existing owner/customer credentials passed login, authenticated reads and logout against the running API. Chrome checks reached both the compiled customer dashboard and staff dashboard. The four initial schemes were seeded as unpublished drafts. Local service status confirms database transactions are available; Razorpay, SMS, email, KYC and push credentials still need configuration.

External acceptance requires Razorpay keys/webhook, SMS sender approval, SMTP, Cashfree access and Firebase configuration. Missing configuration fails explicitly, without fabricated success. Native signing/APNs, container deployment and production TLS have not been validated on this Windows workstation.

Optional offline contributions are not enabled. Store-specific legal/accounting text and product invoices must come from the store. Initial scheme terms are reviewable drafts, not automatically published policy.
