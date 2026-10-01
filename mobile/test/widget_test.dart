import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_shop_scheme/main.dart';

void main() {
  testWidgets('customer dashboard displays the published admin banner',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Dashboard(
      auth: FakeAuthService(),
      email: 'customer@example.com',
      onBrowse: () {},
      onPayments: () {},
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Published promotion'), findsOneWidget);
    expect(find.text('Admin banner message'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('signup requests verification before offering account creation',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: RegistrationPage(auth: FakeAuthService())));
    await tester.pumpAndSettle();
    expect(find.text('Send email verification code'), findsOneWidget);
    expect(find.text('Verify and create account'), findsNothing);
    await tester.enterText(find.byType(TextFormField).at(0), 'New customer');
    await tester.enterText(find.byType(TextFormField).at(1), 'new@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), '+919888888888');
    await tester.enterText(
        find.byType(TextFormField).at(3), 'new-password-123');
    await tester.tap(find.text('Send email verification code'));
    await tester.pumpAndSettle();
    expect(find.text('Send phone verification code'), findsOneWidget);
    await tester.ensureVisible(find.text('Verify and create account'));
    await tester.pumpAndSettle();
    expect(find.text('Verify and create account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('registration fields reject invalid contact and short password inputs',
      () {
    const phone = InputField('phone', 'Phone', phone: true);
    expect(phone.validate('9876543210'), isNotNull);
    expect(phone.validate('+91 9876543210'), isNotNull);
    expect(phone.validate('+919876543210'), isNull);
    expect(
        const InputField('password', 'Password', secret: true, minLength: 8)
            .validate('short'),
        isNotNull);
    expect(const InputField('email', 'Email', email: true).validate('invalid'),
        isNotNull);
  });
  testWidgets('reset password validates confirmation and returns to sign in',
      (tester) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(MaterialApp(
        home: ResetPasswordPage(auth: auth, token: 'xxxxxxxxxxxxxxxxxxxx')));
    await tester.pumpAndSettle();
    expect(find.text('Set a new password'), findsOneWidget);
    expect(find.text('New password'), findsOneWidget);
    expect(find.text('Confirm new password'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'short');
    await tester.enterText(find.byType(TextFormField).at(1), 'different');
    await tester.ensureVisible(find.text('Update password'));
    await tester.tap(find.text('Update password'));
    await tester.pump();
    expect(find.text('Use at least 8 characters'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Valid123!');
    await tester.enterText(find.byType(TextFormField).at(1), 'Other123!');
    await tester.ensureVisible(find.text('Update password'));
    await tester.tap(find.text('Update password'));
    await tester.pump();
    expect(find.text('Passwords do not match'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(1), 'Valid123!');
    await tester.ensureVisible(find.text('Update password'));
    await tester.tap(find.text('Update password'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
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
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byTooltip('Notifications'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    expect(find.byTooltip('Sign out'), findsNothing);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Sign out'), 200,
        scrollable: find
            .descendant(
                of: find.byType(ProfilePage), matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
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
    if (path == '/banner') {
      return {
        'mode': 'content',
        'title': 'Published promotion',
        'body': 'Admin banner message',
        'slides': []
      };
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
