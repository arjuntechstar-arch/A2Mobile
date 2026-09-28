from datetime import datetime, timezone
from uuid import uuid4
from fastapi import APIRouter, Depends, Request
from app.dependencies import get_current_user, require_permission
from app.models import UserRecord

router=APIRouter(tags=["operations"])
def db(request:Request): return request.app.state.database.database
@router.get("/notifications")
def notifications(request:Request,user:UserRecord=Depends(get_current_user)): return list(db(request).notifications.find({"user_id":user.id},{"_id":0}))
@router.post("/support/tickets")
def ticket(payload:dict,request:Request,user:UserRecord=Depends(get_current_user)):
    item={"_id":str(uuid4()),"user_id":user.id,"subject":payload.get("subject"),"message":payload.get("message"),"status":"OPEN","created_at":datetime.now(timezone.utc)}; db(request).support_tickets.insert_one(item); return {"id":item["_id"],"status":"OPEN"}
@router.get("/admin/reports/summary")
def report(request:Request,_:UserRecord=Depends(require_permission("report:read"))):
    database=db(request); return {"customers":database.users.count_documents({"role":"customer"}),"active_enrollments":database.enrollments.count_documents({"status":"ACTIVE"}),"completed_enrollments":database.enrollments.count_documents({"status":"COMPLETED"}),"overdue_installments":database.installments.count_documents({"status":"OVERDUE"}),"pending_kyc":database.kyc_verifications.count_documents({"status":"PENDING"})}
