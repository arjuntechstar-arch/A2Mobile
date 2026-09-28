from app.timeutils import utcnow
from fastapi import APIRouter, Depends, Request
from app.dependencies import get_current_user, require_permission
from app.models import UserRecord
from app.services.lifecycle import refresh_enrollment

router = APIRouter(tags=["lifecycle"])


def db(request: Request):
    return request.app.state.database.database


@router.post("/admin/jobs/refresh-lifecycle")
def refresh(
    request: Request,
    _: UserRecord = Depends(require_permission("reconciliation:manage")),
):
    database = request.app.state.database
    completed = sum(
        1
        for item in db(request).enrollments.find({"status": "ACTIVE"})
        if database.transaction(
            lambda session: refresh_enrollment(
                db(request), item["_id"], session=session
            )
        )
    )
    overdue = (
        db(request)
        .installments.update_many(
            {"status": "DUE", "overdue_at": {"$lt": utcnow()}},
            {"$set": {"status": "OVERDUE"}},
        )
        .modified_count
    )
    return {"completed": completed, "overdue": overdue}


@router.get("/enrollments/{enrollment_id}/eligibility")
def eligibility(
    enrollment_id: str, request: Request, user: UserRecord = Depends(get_current_user)
):
    item = db(request).enrollments.find_one({"_id": enrollment_id, "user_id": user.id})
    return {
        "eligible": bool(item and item["status"] == "COMPLETED"),
        "eligible_value_paise": item.get("eligible_value_paise", 0) if item else 0,
    }
