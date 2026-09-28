from datetime import date
from fastapi import APIRouter, Depends, Request
from app.dependencies import get_current_user, require_permission
from app.models import UserRecord
from app.services.lifecycle import refresh_enrollment

router=APIRouter(tags=["lifecycle"])
def db(request:Request): return request.app.state.database.database
@router.post("/admin/jobs/refresh-lifecycle")
def refresh(request:Request,_:UserRecord=Depends(require_permission("reconciliation:manage"))):
    completed=sum(1 for item in db(request).enrollments.find({"status":"ACTIVE"}) if refresh_enrollment(db(request),item["_id"]))
    overdue=db(request).installments.update_many({"status":"DUE","due_date":{"$lt":date.today()}},{"$set":{"status":"OVERDUE"}}).modified_count
    return {"completed":completed,"overdue":overdue}
@router.get("/enrollments/{enrollment_id}/eligibility")
def eligibility(enrollment_id:str,request:Request,user:UserRecord=Depends(get_current_user)):
    item=db(request).enrollments.find_one({"_id":enrollment_id,"user_id":user.id})
    return {"eligible":bool(item and item["status"]=="COMPLETED"),"eligible_value_paise":item.get("eligible_value_paise",0) if item else 0}
