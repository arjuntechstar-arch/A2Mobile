# Implementation review and test guide

> Historical review from before the implementation work. Findings below describe that earlier revision. See [current implementation status](23-IMPLEMENTATION-STATUS.md) and [current setup/test flow](22-SETUP-AND-TESTING.md).

Reviewed 2026-09-28. Scope: all 23 existing files in `docs/` (README and 00–21), all backend routes/services/tests, both client implementations, configuration, and current local validation. There is no `doc/` directory.

## Verdict

The documented application is **not fully implemented**. Authentication is usable in both clients. Later phases have partial backend endpoints, but most customer/admin screens and external integrations are absent. The implementation records describe more capability than is usable end to end. Providing credentials alone will not complete the missing integrations.

No application code was changed during this review. The checks below did not create financial transactions or modify customer verification states.

## Document-by-document assessment

| Document | Assessment |
| --- | --- |
| README | Describes the target stack, not a completed product. Flutter has generated Android/web runners; iOS runner is absent. |
| 00 Master prompt | Full customer/admin journeys are not delivered. Financial idempotency and real provider integration requirements are unmet. |
| 01 Product requirements | Roles exist; most customer/admin features and configurable policy rules are missing. |
| 02 Architecture | Flutter, React, FastAPI, MongoDB exist. External adapters, scheduled jobs, and consistent service/repository separation are missing. |
| 03 Database | Some collections/indexes exist. Required installment uniqueness, payment reference uniqueness, operational query indexes, profiles, nominees and other models are missing. |
| 04 Mobile app | Sign-in, session restoration, placeholder home and sign-out only. No bottom navigation, registration, OTP, catalog, KYC, enrollment, payments, history, receipts, notifications or profile screens. |
| 05 Admin dashboard | Sign-in, identity/role display and sign-out only. No operational dashboard/navigation or management screens. Customer accounts are not rejected by the portal UI, although protected backend APIs enforce permissions. |
| 06 Scheme rules | Integer paise, create/read/update, version records and enrollment snapshots exist. Missing policy fields, deactivation workflow, default-plan seeding and concurrency-safe version writes. Completion checks are insufficient. |
| 07 Razorpay | Local synthetic order IDs, HMAC verification and event storage exist. No gateway order API, checkout, capture reconciliation, payment history, receipts or payment notifications. |
| 08 KYC | PAN format validation/masking, status and manual admin verification exist. No provider submission/result verification, identity integration or provider reference. Manual status changes do not establish provider-backed identity verification. |
| 09 API | 27 runtime paths, with multiple methods on some. Missing logout/revocation, GET/PATCH `/api/me`, identity start, enrollment listing, payment listing and receipts. Identity is `/api/auth/me`. Webhook is `/api/payments/webhooks/razorpay`, not the documented `/api/webhooks/razorpay`. Pagination is absent. |
| 10 Security | Password hashing, JWT checks, RBAC, Flutter token storage, headers and configured CORS exist. No login/OTP throttling, refresh-token revocation/rotation enforcement, sensitive-field encryption or robust financial state transitions. Audit records have method/path/status but no actor/time/change details. |
| 11 Notifications/support | Notification listing and ticket creation only. No FCM/device registration, reminders, delivery, read-state/deep-link handling or support status workflow. |
| 12 Redemption/refunds | Request/complete redemption and pending refund records exist. Missing single-redemption enforcement, customer verification, full accounting references, term-based refund eligibility and gateway refund execution. |
| 13 Reporting | Five summary counts only. No collection, liability, payment, reconciliation, redemption or refund reports/exports. |
| 14 Testing | Seven backend tests and two Flutter tests pass, but broad domain, real MongoDB, provider, concurrency and full E2E coverage are absent. No admin test script/suite. |
| 15 Roadmap | Phase 1 substantially present; phases 2–8 partial; phase 9 incomplete. |
| 16 Deployment | Example environment and local run instructions exist. No complete deployment/CI, backup/restore, monitoring or production TLS setup found. Several provider variables are not wired into runtime configuration. |
| 17 Definition of done | Not met. A complete Pay Installment vertical flow is absent; provider placeholders remain. |
| 18 Phase 1 record | Authentication claims broadly match code. Current verification now includes Flutter checks and a working local MongoDB/API. |
| 19 Phase 2 record | Challenge generation/storage exists, but SMS/email transports are absent, not merely awaiting credentials. Real MongoDB datetime handling is broken. No registration/verification UI. |
| 20 Phase 3 record | Scheme versioning API exists; client catalog/admin management do not. Concurrent edits are not safely coordinated. |
| 21 Phases 4–9 record | Overstates readiness. Installment persistence is broken, payment orders are synthetic, webhooks only store events, and later workflows are incomplete. |

## Blocking findings

1. **Enrollment can leave partial records and fail.** `backend/app/routes/enrollments.py:36` inserts a Python `datetime.date`, which BSON cannot encode. The enrollment is inserted before installments and there is no transaction. `routes/lifecycle.py` also sends `date.today()` in a MongoDB query. Isolated BSON encoding reproduced `InvalidDocument`.
2. **Phone/email verification expiry fails with default MongoDB decoding.** `database.py:9` does not enable timezone-aware decoding; `services/verification.py:15` and `:20` compare decoded naive timestamps with aware UTC timestamps. BSON round-trip reproduced `TypeError`. Verification deletes the challenge before checking it, so even an incorrect attempt consumes it.
3. **OTP/email delivery is absent.** `services/verification.py` generates challenges but sends nothing; registration/send-OTP routes discard returned values. A customer cannot finish normal onboarding through the provided API/client flow.
4. **Payment integration is incomplete.** `routes/payments.py:15` creates `order_<uuid>` locally, with no Razorpay request. Callback verification marks records paid without authoritative capture reconciliation. Webhooks store events but do not update payment/installment state. Repeated callbacks return conflicts and concurrent processing is not coordinated. Required payment uniqueness indexes are absent.
5. **Completion can grant benefit too early.** `services/lifecycle.py` only checks that every existing installment is paid; it does not check expected installment count, amounts or reconciliation. Isolated test with one paid installment on a two-installment plan returned completed.
6. **Repeat redemption is possible from the code path.** Redemption completion does not consume the enrollment eligibility; there is no unique enrollment redemption constraint or atomic reservation. Refund creation accepts an unvalidated dictionary without eligibility/amount checks or gateway execution. These are code-review findings, not live financial tests.
7. **Scheme edits fail browser preflight.** PUT exists on the scheme route, but `main.py:32` omits PUT from allowed CORS methods. Local preflight returned 400 `Disallowed CORS method`.
8. **Due-date/payment lifecycle is incomplete.** Due dates are always the first of the month, including a potentially past first installment. No configurable grace/missed-payment policy. Payment order lookup accepts only DUE, so OVERDUE installments become unpayable through that endpoint.

## Validation performed

- Backend: `python -m pytest -q` — **7 passed**, one dependency deprecation warning. These use in-memory doubles, not real MongoDB workflow tests.
- Flutter: `flutter test` — **2 passed**; `flutter analyze` — **no issues**.
- Admin: TypeScript plus Vite production build using Node 22 — **passed**. This is build validation, not UI/E2E coverage.
- Runtime OpenAPI route inventory checked.
- Isolated BSON serialization, timestamp comparison and incomplete-installment completion reproductions confirmed the findings above.
- Browser CORS preflight confirmed PUT rejection.
- Previous local browser verification confirmed customer login reaches the signed-in placeholder screen.

## What you can test now

### 1. Customer sign-in flow

1. Open `http://localhost:5174` and refresh the page.
2. Use the local customer credentials shared in the conversation. Credentials are deliberately not copied into this tracked document.
3. Enter an incorrect password first: expect an error and remain on the login screen.
4. Enter the correct credentials: expect `Signed in as customer@example.com` and the placeholder dashboard message.
5. Refresh: expect the session to restore.
6. Sign out: expect the login form. Refresh again: expect to remain signed out.

This is the current customer UI boundary. Scheme selection/payment screens do not exist yet. Browser validation does not establish Android/iOS readiness.

### 2. Admin sign-in flow

1. Open `http://127.0.0.1:5173`.
2. Sign in using the bootstrap account from the root `.env` (`BOOTSTRAP_SUPER_ADMIN_EMAIL` and its password). Bootstrap only creates a missing account; editing the password variable does not reset an existing account.
3. Expect the welcome screen and `super_admin` role.
4. Refresh to check session restoration, then sign out.

Operational dashboard screens do not exist yet. Use backend API checks for implemented administration endpoints.

### 3. API authentication and permissions

Open `http://127.0.0.1:8000/docs`.

1. Execute `POST /api/auth/login` with a local account. Expect access and refresh tokens.
2. Click **Authorize** and paste only the access token into the HTTPBearer field.
3. Execute `GET /api/auth/me`; expect the correct email/role/permissions.
4. Execute `POST /api/auth/refresh` with the refresh token; expect a new token pair.
5. With customer authorization, `GET /api/admin/reports/summary` should return 403.
6. Clear authorization; `GET /api/auth/me` should return 401.
7. Authorize as super admin; the report summary should return 200 and counts.

Sign-out currently removes client tokens only; it does not revoke previously issued tokens on the server.

### 4. Scheme API flow (creates local test data)

Authorize as super admin, then execute `POST /api/schemes` with a unique code:

```json
{
  "code": "QA500_20260928",
  "name": "QA monthly 500",
  "monthly_amount_paise": 50000,
  "installment_count": 11,
  "benefit_paise": 50000
}
```

Expect 201 and version 1. Save the ID. Check `GET /api/schemes` and `GET /api/schemes/{id}`. PUT a revised name with the complete payload and expect version 2. Swagger shares the API origin, so this does not demonstrate that the separate browser admin origin can edit schemes. Repeating the create with the same code should return 409. A customer attempting create/update should receive 403.

The example represents INR 5,500 contribution plus INR 500 benefit, but this calculation is not proof of a working payment/enrollment flow.

### 5. Limited API smoke tests

- `GET /api/kyc/status`: inspect state. PAN submission records PENDING only; it does not verify identity. Do not use manual verification as proof of KYC provider integration.
- `GET /api/notifications`: returns the user's stored notifications, often empty. There is no delivery pipeline.
- `POST /api/support/tickets` with `{"subject":"QA test","message":"Local smoke test"}` creates an OPEN ticket. Subsequent support handling is absent.
- A new/unverified customer attempting enrollment should get 422. Do not bypass verification to claim E2E success; even a fully verified customer reaches the date persistence defect.

## Full acceptance flow after missing work is completed

Register -> delivered phone OTP/email verification -> login -> browse/versioned scheme -> provider-backed KYC -> accept terms -> enrollment and complete installment schedule -> actual Razorpay test-mode order/checkout -> signed callback and webhook in either order -> reconciliation -> payment history/receipt/notification -> repeat all qualifying installments -> completion and benefit -> single authorized redemption with invoice/store/customer verification -> accounting reports and complete audit history.

Then test payment failures, pending/cancelled payments, duplicate/out-of-order events, concurrent taps, incorrect amounts/signatures, network interruption, overdue recovery, cancellation/refund policy and token/permission failures. This acceptance flow is currently blocked and should not be reported as passed.

## Recommended implementation order

1. Fix BSON dates/timezones, CORS, lifecycle completeness, atomic state transitions, uniqueness constraints and regression coverage against MongoDB.
2. Implement SMS/email delivery and provider-backed KYC with test-mode adapters.
3. Deliver customer/admin scheme and enrollment screens against verified APIs.
4. Implement actual Razorpay orders/checkout/reconciliation, receipts and payment history.
5. Complete redemption/refund, notifications/support/reporting and their screens.
6. Add full E2E/concurrency/security checks and deployment/backup/restore validation before declaring the documented product complete.
