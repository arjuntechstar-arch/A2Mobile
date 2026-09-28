# Definition of Done

A UI screen alone is not complete. For Pay Installment: Flutter UI →
authenticated API → authorization → enrollment/installment validation →
authoritative amount → Razorpay order → checkout → signature
verification → webhook/reconciliation → payment persistence →
installment update → receipt → notification → admin visibility → audit
log → automated tests.

Before completing a phase: backend tests pass; mobile checks pass; admin
tests/type/lint/build pass; no fake required implementations remain;
security-sensitive flows reviewed; docs updated.
