# Demo data for application testing

Run from the project root:

```powershell
.\seed-demo.ps1 -Preview
.\seed-demo.ps1
```

The command adds synthetic records to the configured development/test database in one transaction. Existing customers, schemes, uploaded banners and published content are preserved. Rerunning creates no duplicates and preserves edits made to demo records. Every demo record is tagged `demo_seed: a2-demo-v1`. Production is excluded.

All demo accounts use password **DemoShop123!**.

| Account | Purpose |
| --- | --- |
| demo.customer@example.com | Two active schemes, completed scheme, pending/completed redemption, pending/processed refund, receipts and support |
| demo.overdue@example.com | Overdue installments |
| demo.completed@example.com | Completed scheme available for requesting redemption |
| demo.redemption@example.com | Pending store redemption |
| demo.refund@example.com | Approved refund |
| demo.new@example.com | Verified customer with no enrollments |
| demo.unverified@example.com | Contact verification required |
| demo.kyc@example.com | KYC requiring review |
| demo.owner@example.com | Full staff portal access |
| demo.admin@example.com | Admin role and permissions |
| demo.accountant@example.com | Reports, reconciliation and refund permissions |
| demo.staff@example.com | Store staff, support and redemption permissions |

Customer app: <http://localhost:5174>. Staff portal: <http://localhost:5173>.

## Coverage

1. Sign in as the main customer; switch active schemes and inspect paid totals, progress and next due dates.
2. Browse published demo schemes; open their terms. The staff portal also contains a draft scheme for publication testing.
3. Open Payments and copy a receipt; open Refunds for pending and processed examples.
4. Open the notification bell, mark an item read, and follow its enrollment link.
5. Edit the encrypted profile, view verified KYC and identity status, and inspect open, in-progress, resolved and closed support tickets.
6. Sign in as the owner to check customers, enrollments, installments, overdue/completed schemes, redemptions, refunds, notifications, stores, audit logs and reports. Existing uploaded banners remain available.
7. Sign in using each staff role to check restricted navigation and permissions.
8. Use the empty and unverified accounts to test first-time states and validation.

Payment histories, receipts, KYC results and redemption/refund outcomes are synthetic database fixtures. The seed sends no emails, SMS or push notifications and makes no payment or identity-provider calls. Creating a new payment, executing a refund, sending a redemption OTP, registration verification, push delivery and fresh provider KYC still use the application's configured integrations; use their sandbox credentials to test those live workflows. Synthetic gateway IDs cannot be reconciled or refunded by a real gateway.

Demo financial totals contribute to local reports alongside existing records. This dataset is intended for the local development application.
