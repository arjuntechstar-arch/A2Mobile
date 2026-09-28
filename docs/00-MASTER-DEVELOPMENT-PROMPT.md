# MASTER DEVELOPMENT PROMPT --- Mobile Shop Scheme Platform

Build a production-ready platform with Flutter Android/iOS apps,
FastAPI/Python backend, MongoDB, React/TypeScript admin dashboard,
Razorpay, OTP/email verification, approved KYC provider integrations,
notifications, receipts, reconciliation, redemption, reports, audit logs
and tests.

## Business model

Initial schemes are ₹500, ₹1,000, ₹1,500 and ₹2,000 monthly. Customer
pays 11 qualifying monthly installments. Initial shop benefit equals one
monthly installment: ₹500→₹5,500+₹500=₹6,000;
₹1,000→₹11,000+₹1,000=₹12,000; ₹1,500→₹16,500+₹1,500=₹18,000;
₹2,000→₹22,000+₹2,000=₹24,000. Keep every rule configurable and
versioned.

## Customer flow

Install → onboarding → register → phone OTP → email verification → login
→ schemes → details → join → PAN/approved identity verification → terms
→ enrollment → monthly Razorpay payments → receipts/progress →
completion → shop benefit → redemption.

## Admin flow

Login → dashboard → customers → schemes → enrollments → KYC → payments →
reconciliation → overdue → completed schemes → redemptions → refunds →
reports → notifications → support → audit logs.

## Mandatory engineering rules

Backend is authoritative for identity, amount, installment, payment
status, KYC status, benefit, completion and redemption. Razorpay secrets
stay backend-only. Verify payment signatures and webhooks. Financial
operations are idempotent. Existing enrollment terms never change when a
scheme is edited. Do not fake KYC or expose sensitive identity
information.
