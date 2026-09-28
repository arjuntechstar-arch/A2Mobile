from app.services.lifecycle import refresh_enrollment

class Collection:
    def __init__(self, values): self.values=values
    def find_one(self, query): return next((x for x in self.values if all(x.get(k)==v for k,v in query.items())),None)
    def find(self, query): return [x for x in self.values if all(x.get(k)==v for k,v in query.items())]
    def update_one(self, query, change):
        item=self.find_one(query); item.update(change["$set"])
class Db:
    def __init__(self):
        self.enrollments=Collection([{"_id":"e1","status":"ACTIVE","terms":{"monthly_amount_paise":50000,"installment_count":2,"benefit_paise":50000}}])
        self.installments=Collection([{"enrollment_id":"e1","status":"PAID"},{"enrollment_id":"e1","status":"PAID"}])
def test_all_paid_installments_complete_enrollment():
    db=Db(); assert refresh_enrollment(db,"e1") is True
    assert db.enrollments.values[0]["status"]=="COMPLETED"
    assert db.enrollments.values[0]["eligible_value_paise"]==150000
