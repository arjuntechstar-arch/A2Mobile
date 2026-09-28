# Deployment

Environment example: MONGODB_URI=mongodb://localhost:27017/
MONGODB_DATABASE=mobile_shop_scheme JWT_SECRET=... JWT_ALGORITHM=HS256
RAZORPAY_KEY_ID=... RAZORPAY_KEY_SECRET=... RAZORPAY_WEBHOOK_SECRET=...
OTP_PROVIDER=... SMS_API_KEY=... KYC_PROVIDER=... KYC_API_KEY=...
FIREBASE_CREDENTIALS=...

Provide .env.example and never commit secrets. Production requires
HTTPS, secure secret management, persistent storage, backups,
monitoring/logging, restricted CORS, environment separation and tested
restore procedures.
