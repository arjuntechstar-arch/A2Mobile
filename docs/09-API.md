# API

Customer examples: POST /api/auth/register POST /api/auth/send-phone-otp
POST /api/auth/verify-phone-otp POST /api/auth/login POST
/api/auth/refresh POST /api/auth/logout GET/PATCH /api/me GET
/api/schemes GET /api/schemes/{id} POST /api/kyc/pan/verify POST
/api/kyc/identity/start GET /api/kyc/status POST/GET /api/enrollments
GET /api/enrollments/{id}/installments POST /api/payments/orders POST
/api/payments/{id}/verify GET /api/payments GET
/api/payments/{id}/receipt GET /api/notifications POST
/api/support/tickets

Gateway: POST /api/webhooks/razorpay

Admin APIs cover dashboard, customers, schemes, enrollments, KYC,
payments/reconciliation, redemptions, refunds, reports, notifications
and audit logs. Use validation, pagination, DTO filtering and RBAC.
