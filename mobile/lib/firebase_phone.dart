import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'api.dart';

class PhoneVerification {
  PhoneVerification(this.auth, this.phone);
  final AuthService auth;
  final String phone;
  FirebaseAuth? _firebase;
  ConfirmationResult? _confirmation;
  String? _verificationId;
  PhoneAuthCredential? _automaticCredential;
  bool _sent = false;
  bool _firebaseMode = false;

  Future<void> send() async {
    _sent = false;
    _automaticCredential = null;
    _confirmation = null;
    _verificationId = null;
    final config = await auth.request('/app-config');
    _firebaseMode = config['phoneVerificationProvider'] == 'firebase';
    if (!_firebaseMode) {
      await auth.request('/auth/send-phone-otp', method: 'POST', body: {'phone': phone});
      _sent = true;
      return;
    }
    final platform = kIsWeb ? 'web' : defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
    final platforms = config['firebase'];
    final options = platforms is Map ? platforms[platform] : null;
    final requiredKeys = ['apiKey', 'appId', 'messagingSenderId', 'projectId', if (kIsWeb) 'authDomain'];
    if (options is! Map || requiredKeys.any((key) => options[key] is! String || (options[key] as String).trim().isEmpty)) {
      throw Exception('Firebase phone verification is not configured for this device.');
    }
    // initializeApp loads the web SDK before accessing it and reuses the named
    // app for matching options. app() cannot safely be used as a bootstrap probe.
    final app = await Firebase.initializeApp(name: 'phone-verification', options: FirebaseOptions(
        apiKey: options['apiKey'], appId: options['appId'],
        messagingSenderId: options['messagingSenderId'], projectId: options['projectId'],
        authDomain: options['authDomain'], storageBucket: options['storageBucket'],
        iosBundleId: options['iosBundleId'],
      ));
    final firebase = FirebaseAuth.instanceFor(app: app);
    _firebase = firebase;
    await firebase.signOut();
    if (kIsWeb) {
      _confirmation = await firebase.signInWithPhoneNumber(phone);
    } else {
      final ready = Completer<void>();
      await firebase.verifyPhoneNumber(phoneNumber: phone,
        verificationCompleted: (credential) { _automaticCredential = credential; if (!ready.isCompleted) ready.complete(); },
        verificationFailed: (error) { if (!ready.isCompleted) ready.completeError(error); },
        codeSent: (id, token) { _verificationId = id; if (!ready.isCompleted) ready.complete(); },
        codeAutoRetrievalTimeout: (id) { _verificationId = id; if (!ready.isCompleted) ready.complete(); });
      await ready.future.timeout(const Duration(seconds: 90));
    }
    _sent = true;
  }

  Future<String> confirmToken(String code) async {
    if (!_sent) throw Exception('Request a verification code first.');
    if (!_firebaseMode) {
      throw Exception('Firebase verification is required to create an account.');
    }
    final firebase = _firebase;
    final confirmation = _confirmation;
    final verificationId = _verificationId;
    if (firebase == null || (kIsWeb && confirmation == null) ||
        (!kIsWeb && _automaticCredential == null && verificationId == null)) {
      throw Exception('Phone verification expired. Request a new code.');
    }
    final UserCredential result;
    if (kIsWeb && confirmation != null) {
      result = await confirmation.confirm(code);
    } else {
      final credential = _automaticCredential ?? PhoneAuthProvider.credential(
        verificationId: verificationId!, smsCode: code);
      result = await firebase.signInWithCredential(credential);
    }
    try {
      final user = result.user;
      if (user == null) throw Exception('Phone verification failed. Request a new code.');
      final token = await user.getIdToken(true);
      if (token == null) throw Exception('Phone verification failed. Request a new code.');
      return token;
    } finally { await firebase.signOut(); }
  }

  Future<void> confirm(String code) async {
    if (!_sent) throw Exception('Request a verification code first.');
    if (!_firebaseMode) {
      await auth.request('/auth/verify-phone-otp', method: 'POST', body: {'phone': phone, 'code': code});
      return;
    }
    final token = await confirmToken(code);
    await auth.request('/auth/verify-phone-firebase', method: 'POST', body: {'id_token': token});
  }
}
