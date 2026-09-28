# Architecture

Flutter/Dart mobile app → HTTPS → FastAPI/Pydantic backend →
service/repository layers → MongoDB. React + TypeScript admin dashboard
uses the same secured API. External adapters: Razorpay, SMS/OTP, email,
approved KYC/identity provider, Firebase Cloud Messaging.

Principles: backend-authoritative financial state, safe integer/Decimal
money calculations, scheme snapshots, immutable transaction history,
RBAC, idempotency, sensitive-data minimization, scheduled
reminder/reconciliation jobs.
