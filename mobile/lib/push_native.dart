import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api.dart';

StreamSubscription<String>? _refreshSubscription;
Future<void> enablePush(AuthService auth) async {
  final config = await auth.request('/app-config');
  final platform =
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  final options = config['firebase'][platform];
  if (options == null) {
    throw Exception(
        'Push notifications have not been configured by the store.');
  }
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
        options: FirebaseOptions(
            apiKey: options['apiKey'],
            appId: options['appId'],
            messagingSenderId: options['messagingSenderId'],
            projectId: options['projectId'],
            storageBucket: options['storageBucket'],
            iosBundleId: options['iosBundleId']));
  }
  final permission = await FirebaseMessaging.instance.requestPermission();
  if (permission.authorizationStatus == AuthorizationStatus.denied) {
    throw Exception('Notification permission was not granted.');
  }
  Future<void> register(String token) => auth.registerPush(token, platform);
  final token = await FirebaseMessaging.instance.getToken();
  if (token == null) {
    throw Exception('Unable to register notifications. Try again later.');
  }
  await register(token);
  await _refreshSubscription?.cancel();
  _refreshSubscription =
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
    unawaited(register(token).catchError((Object _) {}));
  });
}
