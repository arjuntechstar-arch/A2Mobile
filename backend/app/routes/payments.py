import hashlib, hmac
from datetime import datetime, timezone
from uuid import uuid4
from fastapi import APIRouter, Depends, Header, HTTPException, Request
from app.dependencies import get_current_user
from app.models import UserRecord

router=APIRouter(prefix="/payments",tags=["payments"])
def db(request:Request): return request.app.state.database.database
@router.post("/orders")
def order(payload:dict,request:Request,user:UserRecord=Depends(get_current_user)):
    installment=db(request).installments.find_one({"enrollment_id":payload.get("enrollment_id"),"number":payload.get("installment_number"),"status":"DUE"})
    enrollment=db(request).enrollments.find_one({"_id":payload.get("enrollment_id"),"user_id":user.id,"status":"ACTIVE"})
    if not installment or not enrollment: raise HTTPException(422,"Installment is not payable")
    oid=f"order_{uuid4().hex}"; db(request).payment_orders.insert_one({"_id":oid,"enrollment_id":enrollment["_id"],"installment_number":installment["number"],"amount_paise":installment["amount_paise"],"status":"CREATED","created_at":datetime.now(timezone.utc)})
    return {"order_id":oid,"amount_paise":installment["amount_paise"],"currency":"INR"}
@router.post("/{order_id}/verify")
def verify(order_id:str,payload:dict,request:Request,user:UserRecord=Depends(get_current_user)):
    database=db(request); order=database.payment_orders.find_one({"_id":order_id,"status":"CREATED"})
    if not order: raise HTTPException(409,"Order is unavailable")
    enrollment=database.enrollments.find_one({"_id":order["enrollment_id"],"user_id":user.id})
    if not enrollment: raise HTTPException(403,"Order does not belong to this customer")
    payment_id=payload.get("razorpay_payment_id",""); signature=payload.get("razorpay_signature","")
    material=f"{order_id}|{payment_id}".encode(); expected=hmac.new(request.app.state.settings.razorpay_key_secret.encode(),material,hashlib.sha256).hexdigest()
    if not request.app.state.settings.razorpay_key_secret or not hmac.compare_digest(expected,signature): raise HTTPException(400,"Invalid payment signature")
    database.payment_orders.update_one({"_id":order_id},{"$set":{"status":"PAID","payment_id":payment_id,"verified_at":datetime.now(timezone.utc)}})
    database.payments.update_one({"gateway_payment_id":payment_id},{"$setOnInsert":{"gateway_payment_id":payment_id,"order_id":order_id,"amount_paise":order["amount_paise"],"status":"CAPTURED","created_at":datetime.now(timezone.utc)}},upsert=True)
    database.installments.update_one({"enrollment_id":order["enrollment_id"],"number":order["installment_number"],"status":"DUE"},{"$set":{"status":"PAID","payment_id":payment_id,"paid_at":datetime.now(timezone.utc)}})
    return {"status":"verified","payment_id":payment_id}
@router.post("/webhooks/razorpay")
async def webhook(request:Request,x_razorpay_signature:str=Header(default="")):
    body=await request.body()
    secret=request.app.state.settings.razorpay_webhook_secret.encode()
    if not secret or not hmac.compare_digest(hmac.new(secret,body,hashlib.sha256).hexdigest(),x_razorpay_signature): raise HTTPException(401,"Invalid webhook signature")
    event=await request.json(); event_id=event.get("event_id") or hashlib.sha256(body).hexdigest()
    if db(request).payment_events.find_one({"_id":event_id}): return {"status":"duplicate"}
    db(request).payment_events.insert_one({"_id":event_id,"payload":event,"received_at":datetime.now(timezone.utc)})
    return {"status":"accepted"}
