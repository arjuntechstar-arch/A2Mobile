# KYC & Identity

Phone verification is required; support email verification. PAN format
validation is not verification: use an appropriate provider and store
verification status/reference/timestamp.

For Aadhaar/identity, do not build unofficial verification or scraping.
Integrate only an authorized/appropriate verification mechanism/provider
for the actual business context. Minimize retention and mask sensitive
identifiers.

Statuses: NOT_SUBMITTED, PENDING, VERIFIED, FAILED, REQUIRES_REVIEW.
Never expose complete sensitive identifiers in logs, URLs, analytics,
push notifications or ordinary admin tables.
