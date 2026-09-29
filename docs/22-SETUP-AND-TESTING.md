# Setup and application test flow

<!-- local-sample-logins:start -->
## Local sample login credentials

These are the verified accounts in this local development database. Do not reuse these documented passwords in production.

| Account | Login page | Email | Password |
| --- | --- | --- | --- |
| Customer | http://localhost:5174 | `customer@example.com` | `Mobile-2c5e435d531f!` |
| Owner / super admin | http://localhost:5173 | `owner@example.com` | `Local-019de0a88df144b9!` |

Use the customer account in the mobile app and the owner account in the staff portal. The customer still needs real contact and KYC verification before enrollment. These accounts are not automatically created in a fresh database by copying this guide.
<!-- local-sample-logins:end -->

## Configuration

Run API and worker from `backend/`; both read the root `.env`. Restart them after configuration changes. Copy `.env.example` on a new installation. Leave unused providers empty rather than entering dummy values.

Payments and refunds use **Razorpay**. Set `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET` and `RAZORPAY_WEBHOOK_SECRET` in the root `.env`. Cashfree settings are exclusively for KYC. Docker Compose passes the same `.env` to API and worker, so no separate gateway change is needed in `compose.yaml`.

| Service | Environment variables | Preparation |
| --- | --- | --- |
| MongoDB | `MONGODB_URI`, `MONGODB_DATABASE` | Writable replica set; the local installation uses `a2local`. |
| Authentication | `JWT_SECRET`, bootstrap email/password | Long random JWT secret. Bootstrap creates the owner once; changing the environment password does not reset an existing account. |
| Encryption | `DATA_ENCRYPTION_KEYS` | Fernet key generated using `Fernet.generate_key()`. First key encrypts; keep prior keys after it during rotation. |
| Razorpay | `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET` | Same-account test keys, automatic capture and signed webhook delivery. |
| SMS | `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_MESSAGING_SERVICE_SID` | Messaging service and regional sender/template onboarding. |
| Email | `EMAIL_SMTP_HOST`, `EMAIL_SMTP_PORT`, `EMAIL_SMTP_USERNAME`, `EMAIL_SMTP_PASSWORD`, `EMAIL_FROM` | STARTTLS SMTP. Suggested service: Amazon SES, with verified sender and permitted recipients. |
| KYC | `CASHFREE_CLIENT_ID`, `CASHFREE_CLIENT_SECRET`, `CASHFREE_ENVIRONMENT` | Cashfree Secure ID, enabled verification products and server IP allowlisting. |
| Push | `FIREBASE_CREDENTIALS`, `FIREBASE_CLIENT_OPTIONS`, `FIREBASE_WEB_VAPID_KEY` | Private server service-account file, public platform config and public web VAPID key. |
| URLs | `PUBLIC_APP_URL`, `CORS_ORIGINS` | App origin for email links; public HTTPS app for DigiLocker. Explicit comma-separated CORS origins. |

`FIREBASE_CLIENT_OPTIONS` is JSON keyed by `web`, `android` and/or `ios`. Each platform contains public `apiKey`, `appId`, `messagingSenderId`, `projectId`, and optional `authDomain`, `storageBucket`, `iosBundleId`. Never put service-account private keys here. Native releases also require platform Firebase setup, APNs on iOS and release signing.

Provider references: [Razorpay orders](https://razorpay.com/docs/api/orders/create/), [Twilio messages](https://www.twilio.com/docs/messaging/api/message-resource), [SES SMTP](https://docs.aws.amazon.com/ses/latest/dg/smtp-connect.html), [Cashfree PAN](https://www.cashfree.com/docs/api-reference/vrs/v2/pan/verify-pan-sync), [DigiLocker consent](https://www.cashfree.com/docs/api-reference/vrs/v2/digilocker/create-digilocker-url), [DigiLocker document](https://www.cashfree.com/docs/api-reference/vrs/v2/digilocker/get-document-from-digilocker), [Firebase setup](https://firebase.google.com/docs/cloud-messaging/flutter/get-started).

## Local processes

Use Python 3.11, Node 22.12+ and Flutter stable. Install `backend/requirements.txt`, run `npm ci` in `admin/` and `flutter pub get` in `mobile/`. From separate terminals:

```powershell
# backend/
..\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

```powershell
# backend/: seed once; keep worker running
..\.venv\Scripts\python.exe -m app.seed
..\.venv\Scripts\python.exe -m app.worker
```

```powershell
# admin/
npm run dev -- --host 127.0.0.1
```

```powershell
# mobile/
flutter run -d chrome --web-port 5174 --dart-define=API_BASE_URL=http://localhost:8000/api
```

Customer app uses port 5174, staff portal 5173, API 8000. `/health/ready` checks writable replica-set availability. Staff **Service configuration** reports presence of configuration, not provider connectivity or account approval. Use `http://10.0.2.2:8000/api` for Android emulator development; a physical device needs a reachable host. Web release API URLs are build-time settings.

The existing local customer can log in before providers are configured. Phone and email verification and accepted terms remain required for enrollment. For local testing only, set `APP_ENVIRONMENT=development` and `LOCAL_SKIP_KYC=true` to enroll without KYC. This does not mark the customer KYC-verified; the enrollment records that KYC was skipped. The flag defaults to false and is rejected outside development. Restart the API after changing it. Sessions created before the session upgrade must sign in again.

## Proposed defaults

Four initial drafts: INR 500, 1,000, 1,500 and 2,000 monthly; 11 installments; shop benefit equal to one installment. Staff reviews and publishes the terms.

- Join any day unless a joining window is set.
- Joining-day anniversary in India Standard Time, clamped at month end; configurable fixed day and UTC calendar.
- Seven grace days; late contributions allowed; no automatic penalty or forfeiture. Late-payment rejection uses the actual deadline even if the worker has not run.
- Future installments open on their due date. Optional advance contributions never accelerate the final maturity date.
- Completion requires the exact installment count, amounts, payment references and reconciled capture status.
- Cancellation requires approval. Default deduction zero; benefits excluded from refunds. Outstanding orders must first be reconciled.
- Redemption valid for 365 days after completion; fresh phone code, active store, product and invoice references, and sufficient invoice value required.
- Reminders at 7, 3, 1 and 0 days before due; weekly overdue reminders.

Scheme edits create draft versions. Existing enrollments retain accepted terms. Suggested operating practice: separate accountant/store-staff access, reconcile daily, and review aging refunds and redemptions weekly.

## Acceptance flow

1. **Staff setup:** Sign in as owner. Review Service configuration. Add an active store. Review and publish initial schemes. Publish your actual contact, FAQ, privacy and legal terms. Seed does not fabricate legal content.
2. **Onboarding:** Register with a phone/email you control. Receive SMS/email, sign in and verify both from Profile. Wrong, expired and reused challenges must fail. Fast resend must be limited. Test forgot/reset password and session revocation.
3. **Profile/KYC:** Edit address/nominee. Submit consent, exact PAN and matching name using provider-approved test data. Partial matches require review. Optional DigiLocker needs HTTPS and matching PAN document verification; consent authentication alone cannot approve identity.
4. **Enrollment:** Open a published scheme, review/accept terms and join. Check enrollment number, complete calendar, progress and next due. Replaying an enrollment request key must return the same record. Unverified customers must be rejected.
5. **Payment:** Pay an available installment with Razorpay test checkout. Configure `POST https://<api-host>/api/webhooks/razorpay` for payment-captured/order-paid events and the configured webhook secret. Confirm one paid installment, receipt, payment, notification and staff-visible record.
6. **Retry/reconciliation:** Cancel checkout and reopen it; the existing order must be reused. Test a failed payment followed by a retry. Redeliver a webhook and repeat the callback: no duplicate credit/receipt. Close the browser before callback; webhook or reconciliation must still record a capture. Ambiguous order creation appears in Reconciliation; use Recover gateway order before another charge.
7. **Completion:** In a separate staging database, publish a one-installment QA scheme for quick acceptance testing. Production monthly schedules stay intact. Check contribution-plus-benefit value after capture/reconciliation. Automated tests control the clock to test multi-month maturity.
8. **Redemption:** Request redemption and a fresh code from My redemptions while at the store. Staff enters code, store ID, product and invoice details. Confirm REDEEMED and exactly one record. Incorrect codes, insufficient invoices and expired eligibility must fail. Repeating completion cannot grant extra value.
9. **Refund:** Use another active multi-installment plan. Pay its first installment, request cancellation, approve as accountant/owner and execute. PROCESSING may precede PROCESSED; worker polls gateway status. Repeated execution reuses identifiers/idempotency keys. Reject a separate cancellation and confirm return to ACTIVE.
10. **Operations:** Open/reply to support tickets, read notifications and enable push on a configured device. Check collection grouping, benefit liability, overdue, completed plans, refunds, redemption and audit. Resource CSV exports contain the visible page; collection reports contain up to 1,000 groups.
11. **Roles:** Create staff/accountant accounts and verify UI/API restrictions. Customer access to staff resources must return 403. Deactivate a customer/change staff access and confirm existing sessions are revoked.

## Automated checks

```powershell
# repository root
$env:TEST_MONGODB_URI='mongodb://127.0.0.1:27017/?replicaSet=a2local'
.\.venv\Scripts\python.exe -m pytest backend/tests -q
cd admin
npm test
npm run lint
npm run build
cd ../mobile
flutter analyze
flutter test
flutter build web
```

Backend tests create/remove isolated `a2_test_*` databases and use real MongoDB transactions. Without the test URI, database tests skip. Provider responses are controlled fixtures: passing these checks is not live-provider acceptance and sends no messages or charges.

## Backup and deployment

From `backend/`, run `python -m app.backup backup <new-directory>`, then `python -m app.backup restore <directory> restore_<unique-name>` for restore verification. Existing databases cannot be overwritten. Backups include personal information, credential hashes and session data: protect archives and retain encryption keys separately. The snapshot backup suits bounded databases; use managed continuous backups when database size exceeds transaction lifetime limits.

`compose.yaml` is a local bundle with a private unauthenticated MongoDB and loopback application ports. Its named volume is separate from Windows database storage. For production use authenticated private MongoDB, managed secrets, TLS ingress, explicit HTTPS CORS, persistent storage and monitored API/worker processes. `APP_ENVIRONMENT=production` validates JWT/encryption/HTTPS and live-provider environment. Mount the private Firebase file into containers when enabled.

Deploy API and worker from the same revision, register the webhook, verify readiness, run staging acceptance and restore checks, and monitor reconciliation-required orders and aging refunds. Container deployment, TLS ingress, APNs and signed Android/iOS releases still need environment-specific validation.
