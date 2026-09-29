import 'package:firebase_core/firebase_core.dart';
// The platform fake verifies bootstrap ordering without contacting Firebase.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_shop_scheme/api.dart';
import 'package:mobile_shop_scheme/firebase_phone.dart';

class ConfigAuth extends AuthService {
  ConfigAuth(this.config);
  final Map<String, dynamic> config;
  @override
  Future<dynamic> request(String path, {String method = 'GET',
    Map<String, dynamic>? body, Map<String, String>? headers, bool retry = true}) async {
    expect(path, '/app-config');
    return config;
  }
}

class BootstrapProbe extends FirebasePlatform {
  final stopped = Exception('Stop before network access');
  bool initialized = false;
  @override
  FirebaseAppPlatform app([String name = '[DEFAULT]']) =>
      throw StateError('App lookup before SDK initialization');
  @override
  Future<FirebaseAppPlatform> initializeApp({String? name, FirebaseOptions? options}) async {
    expect(name, 'phone-verification');
    expect(options?.projectId, 'test-project');
    initialized = true;
    throw stopped;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('phone bootstrap initializes SDK before attempting app lookup', () async {
    final previous = Firebase.delegatePackingProperty;
    final probe = BootstrapProbe();
    Firebase.delegatePackingProperty = probe;
    addTearDown(() => Firebase.delegatePackingProperty = previous);
    const options = {'apiKey': 'test-key', 'appId': 'test-app',
      'messagingSenderId': '123', 'projectId': 'test-project', 'authDomain': 'test-project.firebaseapp.com'};
    final verification = PhoneVerification(ConfigAuth({
      'phoneVerificationProvider': 'firebase',
      'firebase': {'android': options, 'web': options},
    }), '+919999999999');
    await expectLater(verification.send(), throwsA(same(probe.stopped)));
    expect(probe.initialized, isTrue);
    await expectLater(verification.confirmToken('123456'),
        throwsA(predicate((e) => e.toString().contains('Request a verification code first'))));
  });

  for (final firebase in [null, <String, dynamic>{}, {'android': {'apiKey': null}, 'web': {'apiKey': null}}]) {
    test('missing Firebase config produces actionable error: $firebase', () async {
      final verification = PhoneVerification(ConfigAuth({
        'phoneVerificationProvider': 'firebase', 'firebase': firebase,
      }), '+919999999999');
      await expectLater(verification.send(), throwsA(predicate((e) =>
          e.toString().contains('not configured for this device'))));
    });
  }
}
