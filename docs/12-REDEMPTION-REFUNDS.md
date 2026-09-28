# Redemption & Refunds

After all qualifying installments are reconciled, backend computes
contribution plus configured benefit and creates redemption eligibility.
Redemption requires authorized server workflow and appropriate customer
verification. Persist redemption references, eligible/redeemed values,
product/invoice references, store, processor, status and audit history.

Cancellation/refund behavior comes from accepted scheme terms and
authorized workflows. Track reason, eligible amount, permitted
deductions, approval, gateway refund ID, status and audit history. Do
not assume every contribution is refundable.
