from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from starlette.requests import Request

from app.config import get_settings
from app.database import MongoDatabase
from app.models import Role
from app.routes import (
    admin,
    auth,
    schemes,
    enrollments,
    payments,
    lifecycle,
    redemptions,
    operations,
)
from app.services.users import MongoUserRepository, UserService
from app.timeutils import utcnow
from starlette.concurrency import run_in_threadpool
from fastapi.responses import JSONResponse
from pymongo.errors import DuplicateKeyError


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    database = MongoDatabase(settings)
    database.ensure_indexes()
    app.state.database = database
    if settings.bootstrap_super_admin_email and settings.bootstrap_super_admin_password:
        users = MongoUserRepository(database)
        if users.by_email(settings.bootstrap_super_admin_email) is None:
            UserService(users).create(
                settings.bootstrap_super_admin_email,
                settings.bootstrap_super_admin_password,
                Role.SUPER_ADMIN,
            )
    yield
    database.close()


settings = get_settings()
app = FastAPI(title="Mobile Shop Scheme API", version="0.1.0", lifespan=lifespan)
app.state.settings = settings


Path(settings.upload_directory).mkdir(parents=True, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=settings.upload_directory), name="uploads")

@app.exception_handler(DuplicateKeyError)
async def duplicate_record(request: Request, exc: DuplicateKeyError):
    return JSONResponse(
        status_code=409,
        content={"detail": "This record already exists. Refresh and try again."},
    )


app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins.split(","),
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Idempotency-Key"],
)
app.include_router(auth.router, prefix="/api")
app.include_router(admin.router, prefix="/api")
app.include_router(schemes.router, prefix="/api")
app.include_router(enrollments.router, prefix="/api")
app.include_router(payments.router, prefix="/api")
app.include_router(lifecycle.router, prefix="/api")
app.include_router(redemptions.router, prefix="/api")
app.include_router(operations.router, prefix="/api")


@app.middleware("http")
async def security_headers_and_audit(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "no-referrer"
    if request.url.path.startswith("/api/") and request.method in {
        "POST",
        "PUT",
        "PATCH",
        "DELETE",
    }:
        # Metadata only: request bodies and sensitive identifiers are never audited.
        try:
            await run_in_threadpool(
                app.state.database.database.audit_logs.insert_one,
                {
                    "method": request.method,
                    "path": request.url.path,
                    "status": response.status_code,
                    "actor_id": getattr(request.state, "actor_id", None),
                    "created_at": utcnow(),
                },
            )
        except AttributeError:
            pass
    return response


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/health/ready")
def ready():
    try:
        status = app.state.database.client.admin.command("hello")
        if not status.get("setName") or not status.get("isWritablePrimary"):
            return JSONResponse(
                status_code=503, content={"status": "database_not_ready"}
            )
    except Exception:
        return JSONResponse(status_code=503, content={"status": "database_unavailable"})
    return {"status": "ready"}
