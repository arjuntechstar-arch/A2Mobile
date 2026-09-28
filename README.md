# Mobile Shop Scheme

Flutter customer app, React staff portal and FastAPI API with MongoDB transactions.
Includes verified onboarding, KYC, versioned schemes, scheduled contributions,
Razorpay checkout/reconciliation, receipts, redemption, refunds, notifications,
support, reports and role-based administration.

Read [setup and the complete testing flow](docs/22-SETUP-AND-TESTING.md) and
[implementation status](docs/23-IMPLEMENTATION-STATUS.md) before acceptance testing.
External integrations require your provider accounts and credentials.

## Run the API

Create a virtual environment, install `backend/requirements.txt`, copy
`.env.example` to `.env`, set a real `JWT_SECRET` and bootstrap password, then:

```powershell
cd backend
python -m uvicorn app.main:app --reload
```

On startup the configured super-admin is created once. Use its email and
password to sign in. MongoDB must be a writable replica set at `MONGODB_URI`.
Set `DATA_ENCRYPTION_KEYS` to a generated Fernet key for profile encryption.
Run `python -m app.seed` once to create the four initial draft schemes, then
run `python -m app.worker` in a separate terminal for lifecycle and reconciliation.

## Run tests

```powershell
$env:TEST_MONGODB_URI='mongodb://127.0.0.1:27017/?replicaSet=a2local'
cd backend
python -m pytest -q
```

## Clients

Integration tests use isolated databases and controlled provider responses.
Without `TEST_MONGODB_URI`, database-dependent tests skip.

`admin/` requires Node 22.12 or later (`npm ci`, `npm test`, `npm run build`). Set
`VITE_API_BASE_URL` when the API is not `http://localhost:8000/api`.

`mobile/` is a Flutter project. Run `flutter pub get` and then
`flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api` for an
Android emulator (use the appropriate reachable host for device/iOS).

For the browser preview use `flutter run -d chrome --web-port 5174
--dart-define=API_BASE_URL=http://localhost:8000/api` on one line. Verify with
`flutter analyze`, `flutter test`, and `flutter build web`.

Customer app: http://localhost:5174. Staff portal: http://localhost:5173.
API docs: http://localhost:8000/docs. Schemes appear after staff publication.
`compose.yaml` provides an optional local MongoDB/API/worker/admin bundle,
with a separate Docker database volume; it is not a production TLS deployment.
