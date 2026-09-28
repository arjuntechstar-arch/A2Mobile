from datetime import datetime, timezone
from uuid import uuid4
from fastapi import APIRouter, Depends, HTTPException, Request, status
from app.dependencies import get_current_user, require_permission
from app.models import UserRecord

router=APIRouter(tags=["redemptions"])
def db(request:Request): return request.app.state.database.database
@router.post("/redemptions",status_code=status.HTTP_201_CREATED)
def request_redemption(payload:dict,request:Request,user:UserRecord=Depends(get_current_user)):
    enrollment=db(request).enrollments.find_one({"_id":payload.get("enrollment_id"),"user_id":user.id,"status":"COMPLETED"})
    if not enrollment: raise HTTPException(422,"Enrollment is not eligible for redemption")
    item={"_id":str(uuid4()),"enrollment_id":enrollment["_id"],"customer_id":user.id,"eligible_value_paise":enrollment["eligible_value_paise"],"status":"PENDING","requested_at":datetime.now(timezone.utc)}
    db(request).redemptions.insert_one(item); return {"id":item["_id"],"status":item["status"],"eligible_value_paise":item["eligible_value_paise"]}
@router.post("/admin/redemptions/{redemption_id}/complete")
def complete(redemption_id:str,payload:dict,request:Request,_:UserRecord=Depends(require_permission("redemption:process"))):
    result=db(request).redemptions.update_one({"_id":redemption_id,"status":"PENDING"},{"$set":{"status":"COMPLETED","invoice_reference":payload.get("invoice_reference"),"store":payload.get("store"),"completed_at":datetime.now(timezone.utc)}})
    if not result.matched_count: raise HTTPException(409,"Redemption is unavailable")
    return {"status":"COMPLETED"}
@router.post("/admin/refunds")
def refund(payload:dict,request:Request,_:UserRecord=Depends(require_permission("reconciliation:manage"))):
    item={"_id":str(uuid4()),"enrollment_id":payload.get("enrollment_id"),"reason":payload.get("reason"),"amount_paise":payload.get("amount_paise"),"status":"PENDING","created_at":datetime.now(timezone.utc)}
    db(request).refunds.insert_one(item); return {"id":item["_id"],"status":"PENDING"}
