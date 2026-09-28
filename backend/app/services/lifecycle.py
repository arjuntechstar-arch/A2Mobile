from datetime import datetime, timezone

def refresh_enrollment(database, enrollment_id):
    enrollment=database.enrollments.find_one({"_id":enrollment_id})
    if not enrollment or enrollment["status"]!="ACTIVE": return False
    due=list(database.installments.find({"enrollment_id":enrollment_id}))
    if due and all(item["status"]=="PAID" for item in due):
        terms=enrollment["terms"]; eligible=terms["monthly_amount_paise"]*terms["installment_count"]+terms["benefit_paise"]
        database.enrollments.update_one({"_id":enrollment_id},{"$set":{"status":"COMPLETED","completed_at":datetime.now(timezone.utc),"eligible_value_paise":eligible}})
        return True
    return False
