# Razorpay Integration

Flow: Pay → backend validates installment → creates Razorpay order →
Flutter checkout → callback → backend signature verification → signed
webhook/reconciliation → persist payment → mark installment paid →
receipt → notification.

Secret keys are backend-only. Never trust client amount or success.
Webhooks are signature-verified and idempotent. Handle webhook/callback
in either order.

Test success, failure, cancel, pending, duplicate callbacks/webhooks,
invalid signatures, wrong amount, unknown order, already-paid
installment, app closure, timeout, refund and double-tap.
