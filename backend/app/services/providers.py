"""Real provider adapters. Missing configuration fails closed; no simulated success."""

import smtplib
import ssl
from email.message import EmailMessage
from urllib.parse import quote

import httpx
from fastapi import HTTPException


def require_config(*values):
    if any(not value or str(value).startswith("replace-") for value in values):
        raise HTTPException(
            503, "This service has not been configured. Contact the store."
        )


class Providers:
    def __init__(self, settings, transport=None):
        self.settings = settings
        self.transport = transport

    def request(self, method, url, **kwargs):
        try:
            with httpx.Client(timeout=20, transport=self.transport) as client:
                response = client.request(method, url, **kwargs)
                response.raise_for_status()
                return response.json()
        except (httpx.HTTPError, ValueError):
            # Provider payloads can contain PANs, OTPs or secrets; never echo them.
            raise HTTPException(
                502,
                "The external service could not complete the request. Please try again.",
            )

    def sms_ready(self):
        s = self.settings
        require_config(
            s.twilio_account_sid, s.twilio_auth_token, s.twilio_messaging_service_sid
        )

    def send_sms(self, phone, message):
        self.sms_ready()
        s = self.settings
        result = self.request(
            "POST",
            f"https://api.twilio.com/2010-04-01/Accounts/{quote(s.twilio_account_sid, safe='')}/Messages.json",
            auth=(s.twilio_account_sid, s.twilio_auth_token),
            data={
                "To": phone,
                "MessagingServiceSid": s.twilio_messaging_service_sid,
                "Body": message,
            },
        )
        if not result.get("sid"):
            raise HTTPException(502, "SMS provider did not accept the message")
        return result["sid"]

    def email_ready(self):
        s = self.settings
        require_config(
            s.email_smtp_host,
            s.email_smtp_username,
            s.email_smtp_password,
            s.email_from,
        )

    def send_email(self, recipient, subject, body):
        self.email_ready()
        s = self.settings
        message = EmailMessage()
        message["From"], message["To"], message["Subject"] = (
            s.email_from,
            recipient,
            subject,
        )
        message.set_content(body)
        try:
            with smtplib.SMTP(s.email_smtp_host, s.email_smtp_port, timeout=20) as smtp:
                smtp.starttls(context=ssl.create_default_context())
                smtp.login(s.email_smtp_username, s.email_smtp_password)
                smtp.send_message(message)
        except (OSError, smtplib.SMTPException):
            raise HTTPException(
                502, "Email could not be delivered. Please request a new message."
            )

    def verify_pan(self, pan, name):
        s = self.settings
        require_config(s.cashfree_client_id, s.cashfree_client_secret)
        if s.cashfree_environment not in {"sandbox", "production"}:
            raise HTTPException(503, "KYC environment is not configured correctly")
        host = "api" if s.cashfree_environment == "production" else "sandbox"
        result = self.request(
            "POST",
            f"https://{host}.cashfree.com/verification/pan",
            headers={
                "x-client-id": s.cashfree_client_id,
                "x-client-secret": s.cashfree_client_secret,
            },
            json={"pan": pan, "name": name},
        )
        if not result.get("reference_id"):
            raise HTTPException(502, "KYC provider returned no verification reference")
        verified = (
            result.get("valid") is True
            and result.get("pan_status") == "VALID"
            and result.get("name_match_result") == "DIRECT_MATCH"
        )
        return {
            "provider": "cashfree",
            "provider_reference": str(result["reference_id"]),
            "environment": s.cashfree_environment,
            "status": (
                "VERIFIED"
                if verified
                else ("REQUIRES_REVIEW" if result.get("valid") else "FAILED")
            ),
        }

    def cashfree(self, method, path, payload=None, params=None):
        s = self.settings
        require_config(s.cashfree_client_id, s.cashfree_client_secret)
        if s.cashfree_environment not in {"sandbox", "production"}:
            raise HTTPException(503, "KYC environment is not configured correctly")
        host = "api" if s.cashfree_environment == "production" else "sandbox"
        return self.request(
            method,
            f"https://{host}.cashfree.com/verification/{path}",
            headers={
                "x-client-id": s.cashfree_client_id,
                "x-client-secret": s.cashfree_client_secret,
            },
            json=payload,
            params=params,
        )

    def razorpay(self, method, path, payload=None, headers=None):
        s = self.settings
        require_config(s.razorpay_key_id, s.razorpay_key_secret)
        return self.request(
            method,
            "https://api.razorpay.com/v1/" + path,
            auth=(s.razorpay_key_id, s.razorpay_key_secret),
            json=payload,
            headers=headers,
        )
