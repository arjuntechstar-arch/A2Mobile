from uuid import uuid4
from fastapi import APIRouter, Depends, HTTPException, Request, Query
from pydantic import BaseModel
from pymongo.errors import DuplicateKeyError
from app.dependencies import require_permission
from app.models import SchemeInput
from app.timeutils import utcnow

router = APIRouter(prefix="/schemes", tags=["schemes"])


def view(item):
    return {**{k: v for k, v in item.items() if k != "_id"}, "id": str(item["_id"])}


@router.get("")
def list_schemes(
    request: Request, skip: int = Query(0, ge=0), limit: int = Query(50, ge=1, le=100)
):
    db = request.app.state.database.database
    return [
        view(x)
        for x in db.schemes.find({"active": True})
        .sort("created_at", -1)
        .skip(skip)
        .limit(limit)
    ]


@router.get("/{scheme_id}")
def get_scheme(scheme_id: str, request: Request):
    item = request.app.state.database.database.schemes.find_one(
        {"_id": scheme_id, "active": True}
    )
    if not item:
        raise HTTPException(404, "Published scheme not found")
    return view(item)


@router.post("", status_code=201)
def create_scheme(
    payload: SchemeInput,
    request: Request,
    user=Depends(require_permission("scheme:manage")),
):
    database = request.app.state.database
    item = {
        "_id": str(uuid4()),
        **payload.model_dump(),
        "version": 1,
        "active": False,
        "created_at": utcnow(),
        "created_by": user.id,
    }

    def write(session):
        database.database.schemes.insert_one(item.copy(), session=session)
        database.database.scheme_versions.insert_one(
            {
                "scheme_id": item["_id"],
                "version": 1,
                "terms": payload.model_dump(),
                "created_at": item["created_at"],
            },
            session=session,
        )

    try:
        database.transaction(write)
    except DuplicateKeyError:
        raise HTTPException(409, "Scheme code already exists")
    return view(item)


@router.put("/{scheme_id}")
def revise_scheme(
    scheme_id: str,
    payload: SchemeInput,
    request: Request,
    user=Depends(require_permission("scheme:manage")),
):
    database = request.app.state.database

    def write(session):
        db = database.database
        old = db.schemes.find_one({"_id": scheme_id}, session=session)
        if not old:
            raise HTTPException(404, "Scheme not found")
        version = old["version"] + 1
        # Every change becomes a draft and requires a new publishing decision.
        item = {
            **old,
            **payload.model_dump(),
            "version": version,
            "active": False,
            "updated_at": utcnow(),
            "updated_by": user.id,
        }
        db.schemes.replace_one(
            {"_id": scheme_id, "version": old["version"]}, item, session=session
        )
        db.scheme_versions.insert_one(
            {
                "scheme_id": scheme_id,
                "version": version,
                "terms": payload.model_dump(),
                "created_at": utcnow(),
            },
            session=session,
        )
        return view(item)

    try:
        return database.transaction(write)
    except DuplicateKeyError:
        raise HTTPException(409, "Scheme code/version conflicts with another change")


class Publication(BaseModel):
    active: bool
    reviewed_version: int


@router.patch("/{scheme_id}/publication")
def publish(
    scheme_id: str,
    payload: Publication,
    request: Request,
    user=Depends(require_permission("scheme:manage")),
):
    db = request.app.state.database.database
    item = db.schemes.find_one({"_id": scheme_id, "version": payload.reviewed_version})
    if not item:
        raise HTTPException(
            409, "Scheme changed; review its latest terms before publishing"
        )
    SchemeInput.model_validate(
        {key: item[key] for key in SchemeInput.model_fields if key in item}
    )
    result = db.schemes.update_one(
        {"_id": scheme_id, "version": payload.reviewed_version},
        {
            "$set": {
                "active": payload.active,
                "published_by": user.id,
                "published_at": utcnow(),
            }
        },
    )
    if not result.matched_count:
        raise HTTPException(409, "Scheme changed; review again")
    return {"active": payload.active, "version": payload.reviewed_version}
