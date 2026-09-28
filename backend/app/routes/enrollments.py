from datetime import date, datetime, timezone
from uuid import uuid4
from fastapi import APIRouter, Depends, HTTPException, Request, status
from app.dependencies import get_current_user, require_permission
from app.models import EnrollmentRequest, KycStatus, KycSubmit, UserRecord

router=APIRouter(tags=["enrollment"])
def db(request:Request): return request.app.state.database.database
@router.post("/kyc/pan/verify",status_code=status.HTTP_202_ACCEPTED)
def submit_pan(payload:KycSubmit,request:Request,user:UserRecord=Depends(get_current_user)):
    # Provider submission is deployment-configured; PAN is masked and never returned.
    db(request).kyc_verifications.replace_one({"user_id":user.id},{"user_id":user.id,"pan_last4":payload.pan[-4:],"status":KycStatus.PENDING,"submitted_at":datetime.now(timezone.utc)},upsert=True)
    return {"status":KycStatus.PENDING}
@router.get("/kyc/status")
def kyc_status(request:Request,user:UserRecord=Depends(get_current_user)):
    item=db(request).kyc_verifications.find_one({"user_id":user.id}); return {"status":item["status"] if item else KycStatus.NOT_SUBMITTED}
@router.post("/admin/kyc/{user_id}/verify")
def verify_kyc(user_id:str,request:Request,_:UserRecord=Depends(require_permission("kyc:review"))):
    result=db(request).kyc_verifications.update_one({"user_id":user_id},{"$set":{"status":KycStatus.VERIFIED,"verified_at":datetime.now(timezone.utc)}})
    if not result.matched_count: raise HTTPException(404,"KYC record not found")
    return {"status":KycStatus.VERIFIED}
@router.post("/enrollments",status_code=status.HTTP_201_CREATED)
def enroll(payload:EnrollmentRequest,request:Request,user:UserRecord=Depends(get_current_user)):
    database=db(request)
    if not payload.accepted_terms or not user.phone_verified or not user.email_verified: raise HTTPException(422,"Verified contact details and accepted terms are required")
    kyc=database.kyc_verifications.find_one({"user_id":user.id})
    if not kyc or kyc["status"]!=KycStatus.VERIFIED: raise HTTPException(422,"Verified KYC is required")
    scheme=database.schemes.find_one({"_id":payload.scheme_id,"active":True})
    if not scheme: raise HTTPException(404,"Active scheme not found")
    version=database.scheme_versions.find_one({"scheme_id":payload.scheme_id,"version":scheme["version"]})
    enrollment_id=str(uuid4()); snapshot={**version["terms"],"version":version["version"]}
    database.enrollments.insert_one({"_id":enrollment_id,"user_id":user.id,"scheme_id":payload.scheme_id,"terms":snapshot,"status":"ACTIVE","accepted_at":datetime.now(timezone.utc)})
    today=date.today()
    for number in range(1,scheme["installment_count"]+1):
        month=today.month+number-1; year=today.year+(month-1)//12; month=(month-1)%12+1
        database.installments.insert_one({"enrollment_id":enrollment_id,"number":number,"amount_paise":scheme["monthly_amount_paise"],"due_date":date(year,month,1),"status":"DUE"})
    return {"id":enrollment_id,"installments":scheme["installment_count"]}
@router.get("/enrollments/{enrollment_id}/installments")
def installments(enrollment_id:str,request:Request,user:UserRecord=Depends(get_current_user)):
    enrollment=db(request).enrollments.find_one({"_id":enrollment_id,"user_id":user.id})
    if not enrollment: raise HTTPException(404,"Enrollment not found")
    return list(db(request).installments.find({"enrollment_id":enrollment_id},{"_id":0}))
