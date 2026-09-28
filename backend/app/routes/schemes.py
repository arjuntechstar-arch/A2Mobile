from datetime import datetime, timezone
from uuid import uuid4
from fastapi import APIRouter, Depends, HTTPException, status, Request
from app.dependencies import require_permission
from app.models import SchemeInput, SchemeView, UserRecord

router=APIRouter(prefix="/schemes",tags=["schemes"])
def db(request: Request): return request.app.state.database.database
def view(item): return SchemeView(id=item["_id"],code=item["code"],name=item["name"],monthly_amount_paise=item["monthly_amount_paise"],installment_count=item["installment_count"],benefit_paise=item["benefit_paise"],version=item["version"],active=item["active"])
@router.get("",response_model=list[SchemeView])
def list_schemes(request: Request): return [view(x) for x in db(request).schemes.find({"active":True})]
@router.get("/{scheme_id}",response_model=SchemeView)
def get_scheme(scheme_id:str,request: Request):
    item=db(request).schemes.find_one({"_id":scheme_id})
    if not item: raise HTTPException(404,"Scheme not found")
    return view(item)
@router.post("",response_model=SchemeView,status_code=status.HTTP_201_CREATED)
def create_scheme(payload:SchemeInput,request: Request,_:UserRecord=Depends(require_permission("scheme:manage"))):
    database=db(request)
    if database.schemes.find_one({"code":payload.code}): raise HTTPException(409,"Scheme code already exists")
    item={"_id":str(uuid4()),**payload.model_dump(),"version":1,"active":True,"created_at":datetime.now(timezone.utc)}
    database.schemes.insert_one(item); database.scheme_versions.insert_one({"scheme_id":item["_id"],"version":1,"terms":payload.model_dump(),"created_at":item["created_at"]})
    return view(item)
@router.put("/{scheme_id}",response_model=SchemeView)
def revise_scheme(scheme_id:str,payload:SchemeInput,request: Request,_:UserRecord=Depends(require_permission("scheme:manage"))):
    database=db(request); old=database.schemes.find_one({"_id":scheme_id})
    if not old: raise HTTPException(404,"Scheme not found")
    version=old["version"]+1; item={**old,**payload.model_dump(),"version":version}
    database.schemes.replace_one({"_id":scheme_id},item); database.scheme_versions.insert_one({"scheme_id":scheme_id,"version":version,"terms":payload.model_dump(),"created_at":datetime.now(timezone.utc)})
    return view(item)
