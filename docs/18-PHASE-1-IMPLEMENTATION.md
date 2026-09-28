# Phase 1 Implementation Record

Implemented: FastAPI service foundation, MongoDB user persistence/indexes,
password hashing, short-lived JWT access tokens, refresh tokens, authenticated
identity endpoint, role-to-permission mapping and super-admin-controlled staff
account creation. The service bootstraps one super-admin only when both
bootstrap environment values are set.

Clients: React/TypeScript admin sign-in with session refresh and Flutter
customer sign-in with platform secure token storage. Both call the backend
rather than containing independent authorization logic.

Verified on 2026-09-25: `python -m pytest` (4 passed), `python -m compileall
-q app`, `npm exec tsc -- -b`, and `npm exec vite build`. Flutter SDK was not
available in the execution environment, so Flutter `analyze` and widget tests
remain to be run on a machine with Flutter installed. A MongoDB service was
also not available; endpoint behavior is covered with an in-memory repository,
while real MongoDB startup is configured through `MONGODB_URI`.
