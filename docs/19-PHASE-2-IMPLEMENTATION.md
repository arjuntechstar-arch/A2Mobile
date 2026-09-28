# Phase 2 Implementation Record

Registration creates a customer account and stores unverified phone/email
state. OTP challenges are salted with the application secret, expire after ten
minutes and are single-use. Email verification links expire after 24 hours and
are single-use. Deployment placeholders for the approved SMS and email
providers are in `.env.example`; live transport tests are intentionally deferred
until credentials are configured.
