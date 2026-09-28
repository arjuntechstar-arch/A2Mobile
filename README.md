# Mobile Shop Scheme — Phase 1

Phase 1 establishes the project foundation: FastAPI + MongoDB authentication and
RBAC, a React/TypeScript admin sign-in client, and a Flutter customer sign-in
client. Scheme, KYC, enrollment and payment functionality intentionally starts
in later phases.

## Run the API

Create a virtual environment, install `backend/requirements.txt`, copy
`.env.example` to `.env`, set a real `JWT_SECRET` and bootstrap password, then:

```powershell
cd backend
python -m uvicorn app.main:app --reload
```

On startup the configured super-admin is created once. Use its email and
password to sign in. MongoDB must be running at `MONGODB_URI`.

## Run tests

```powershell
cd backend
python -m pytest
```

## Clients

`admin/` is a Vite React project (`npm install; npm run build`). Set
`VITE_API_BASE_URL` when the API is not `http://localhost:8000/api`.

`mobile/` is a Flutter project. Run `flutter pub get` and then
`flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api` for an
Android emulator (use the appropriate reachable host for device/iOS).
