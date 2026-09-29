import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_shop_scheme/main.dart';

void main() {
  test('registration fields reject invalid contact and short password inputs', () {
    const phone = InputField('phone', 'Phone', phone: true);
    expect(phone.validate('9876543210'), isNotNull);
    expect(phone.validate('+91 9876543210'), isNotNull);
    expect(phone.validate('+919876543210'), isNull);
    expect(const InputField('password', 'Password', secret: true, minLength: 12).validate('short'), isNotNull);
    expect(const InputField('email', 'Email', email: true).validate('invalid'), isNotNull);
  });
  testWidgets('shows the authentication entry point', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const SchemeApp());
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsNWidgets(2));
  });

  testWidgets('successful login and logout update the session screen',
      (tester) async {
    await tester
        .pumpWidget(MaterialApp(home: SessionGate(auth: FakeAuthService())));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).at(0), 'customer@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'test-password');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.textContaining('Signed in as customer@example.com'),
        findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('customer can navigate to catalog, payments and profile',
      (tester) async {
    final auth = FakeAuthService()..email = 'customer@example.com';
    await tester.pumpWidget(MaterialApp(home: SessionGate(auth: auth)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schemes'));
    await tester.pumpAndSettle();
    expect(find.text('The store has not published any schemes yet.'),
        findsOneWidget);
    await tester.tap(find.text('Payments'));
    await tester.pumpAndSettle();
    expect(find.text('No reconciled payments yet.'), findsOneWidget);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Phone verification'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('due dates are displayed in the scheme calendar timezone', () {
    expect(
        dueDate('2026-01-31T18:30:00Z', {
          'policy': {'timezone': 'Asia/Kolkata'}
        }),
        '2026-02-01');
    expect(
        dueDate('2026-01-31T18:30:00Z', {
          'policy': {'timezone': 'UTC'}
        }),
        '2026-01-31');
  });
}

class FakeAuthService extends AuthService {
  String? email;
  @override
  Future<String> login(String email, String password) async {
    this.email = email;
    return email;
  }

  @override
  Future<String?> restoreEmail() async => email;
  @override
  Future<void> logout() async {
    email = null;
  }

  @override
  Future<dynamic> request(String path,
      {String method = 'GET',
      Map<String, dynamic>? body,
      Map<String, String>? headers,
      bool retry = true}) async {
    if (path == '/dashboard') {
      return {'enrollments': [], 'unread_notifications': 0};
    }
    if (path == '/me') {
      return {
        'name': 'Test customer',
        'email': email,
        'phone': null,
        'phone_verified': false,
        'email_verified': false,
        'profile': {}
      };
    }
    return [];
  }
}
