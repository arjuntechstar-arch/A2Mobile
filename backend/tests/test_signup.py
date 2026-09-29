import re
import time
import pytest
from fastapi import HTTPException
from test_workflows import system
from app.routes import auth
from app.services.providers import Providers


def prepare(system, monkeypatch):
    client, mongo, root, customer, user, settings = system
    settings.phone_verification_provider = 'firebase'
    sent = []
    monkeypatch.setattr(Providers, 'email_ready', lambda self: None)
    monkeypatch.setattr(Providers, 'send_email', lambda self, *args: sent.append(args[-1]))
    payload = dict(name='New customer', email='new@example.com', phone='+919888888888', password='new-password-123')
    assert client.post('/api/auth/registration/email', json={'email': payload['email']}).status_code == 202
    assert not mongo.database.users.find_one({'email': payload['email']})
    payload['email_code'] = re.search(r'code is ([A-F0-9]{8})', sent[0]).group(1)
    payload['firebase_id_token'] = 'firebase-test-proof-token'
    monkeypatch.setattr(auth, 'verify_phone_token', lambda *args: {
        'phone_number': payload['phone'], 'auth_time': time.time(), 'firebase': {'sign_in_provider': 'phone'}})
    return payload


def test_signup_requires_both_proofs_and_consumes_email(system, monkeypatch):
    client, mongo, *_ = system
    payload = prepare(system, monkeypatch)
    assert client.post('/api/auth/register', json={k:v for k,v in payload.items() if k != 'firebase_id_token'}).status_code == 422
    assert client.post('/api/auth/register', json={**payload, 'email_code': 'WRONG123'}).status_code == 400
    assert not mongo.database.users.find_one({'email': payload['email']})
    result = client.post('/api/auth/register', json=payload)
    assert result.status_code == 201, result.text
    saved = mongo.database.users.find_one({'email': payload['email']})
    assert saved['email_verified'] and saved['phone_verified']
    assert saved['password_hash'] != payload['password']
    assert client.post('/api/auth/register', json=payload).status_code == 400


@pytest.mark.parametrize('failure', ['mismatch', 'expired', 'invalid'])
def test_signup_rejects_invalid_phone_without_account(system, monkeypatch, failure):
    client, mongo, *_ = system
    payload = prepare(system, monkeypatch)
    def proof(*args):
        if failure == 'invalid': raise HTTPException(401, 'Invalid token')
        return {'phone_number': '+919000000000' if failure == 'mismatch' else payload['phone'],
                'auth_time': time.time() - (700 if failure == 'expired' else 0),
                'firebase': {'sign_in_provider': 'phone'}}
    monkeypatch.setattr(auth, 'verify_phone_token', proof)
    assert client.post('/api/auth/register', json=payload).status_code in (401, 403)
    assert not mongo.database.users.find_one({'email': payload['email']})


def test_delivery_failure_creates_no_account(system, monkeypatch):
    client, mongo, *_ = system
    monkeypatch.setattr(Providers, 'email_ready', lambda self: None)
    def fail(*args): raise HTTPException(502, 'Delivery failed')
    monkeypatch.setattr(Providers, 'send_email', fail)
    assert client.post('/api/auth/registration/email', json={'email':'failed@example.com'}).status_code == 502
    assert not mongo.database.users.find_one({'email':'failed@example.com'})


def test_customer_edit_permissions_verification_and_sessions(system):
    client, mongo, root, customer, user, settings = system
    path = f'/api/admin/customers/{user.id}'
    assert client.patch(path, headers=customer, json={'name':'No permission'}).status_code == 403
    assert client.patch(path, headers=root, json={'email_verified': True}).status_code == 422
    assert client.patch(path, headers=root, json={'name':'Edited customer'}).status_code == 200
    assert mongo.database.users.find_one({'_id':user.id})['email_verified'] is True
    mongo.database.email_verifications.insert_one({'user_id':user.id, 'digest':'old-email-proof'})
    result = client.patch(path, headers=root, json={'email':'edited@example.com','phone':'+919777777777'})
    assert result.status_code == 200
    saved = mongo.database.users.find_one({'_id':user.id})
    assert not saved['email_verified'] and not saved['phone_verified']
    assert mongo.database.email_verifications.count_documents({'user_id':user.id}) == 0
    assert client.get('/api/auth/me', headers=customer).status_code == 401


def test_admin_customer_edit_duplicate_rejected(system):
    client, mongo, root, customer, user, settings = system
    r = client.patch(f'/api/admin/customers/{user.id}', headers=root, json={'email':'owner@example.com'})
    assert r.status_code == 409
    assert mongo.database.users.find_one({'_id':user.id})['email'] == 'customer@example.com'
