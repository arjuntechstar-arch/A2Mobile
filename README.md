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
For a complete local demo dataset and test accounts, run `.\seed-demo.ps1` from the project root. See [Demo data and testing scenarios](docs/24-DEMO-DATA.md).

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

On Windows, `./run-app.ps1` starts the local services, launches a configured
Flutter-compatible Android emulator when needed, waits for Android to boot,
then runs the customer app on it. Flutter requires an x86_64 or ARM AVD; use
`./run-app.ps1 -WebOnly` to start only the web previews and local services.

### Wireless Android phone

Enable **Developer options → Wireless debugging** on the phone and keep the
phone and PC on the same Wi-Fi network. The pairing port and the device port
are different. On the first run, select **Pair device with pairing code** and
run (replace each example value with the value shown on the phone):

```powershell
.\run-phone.ps1 -PairEndpoint '192.168.1.8:38609' -PairingCode '652109' -WirelessDevice '192.168.1.8:39407'
```

For later runs, Android normally keeps the pairing and only needs the device
IP address and port shown on the main Wireless debugging screen:

```powershell
.\run-phone.ps1 -WirelessDevice '192.168.1.8:39407'
```

The script starts the API, admin portal, and customer web preview, runs
`adb reverse tcp:8000 tcp:8000` for the phone, and launches Flutter with the
local API at `http://127.0.0.1:8000/api`. If Android changes the device port,
copy the new value from the phone and run the later command again.

`http://127.0.0.1:5174` is the customer web preview on the **PC only**. To
open that preview automatically on the PC, add `-OpenBrowser`. To open it in
the phone browser on the same Wi-Fi, add `-ShareCustomerWeb`; the script prints
the PC Wi-Fi URL to use, for example `http://192.168.1.10:5174`.

For the browser preview use `flutter run -d chrome --web-port 5174
--dart-define=API_BASE_URL=http://localhost:8000/api` on one line. Verify with
`flutter analyze`, `flutter test`, and `flutter build web`.

Customer app: http://localhost:5174. Staff portal: http://localhost:5173.
API docs: http://localhost:8000/docs. Schemes appear after staff publication.
`compose.yaml` provides an optional local MongoDB/API/worker/admin bundle,
with a separate Docker database volume; it is not a production TLS deployment.
