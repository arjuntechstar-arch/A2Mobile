# MongoDB Design

Database: mobile_shop_scheme Development URI: mongodb://localhost:27017/

Collections: users, customer_profiles, admins, roles, permissions,
schemes, scheme_versions, enrollments, installments, payment_orders,
payments, payment_events, refunds, kyc_verifications, addresses,
nominees, redemptions, receipts, notifications, notification_devices,
support_tickets, stores, audit_logs, settings.

Important uniqueness/indexes: phone/email where applicable, scheme code,
enrollment number, enrollmentId+installmentNumber, gateway event/payment
references, payment status/date, enrollment status, KYC status and
installment due date.
