import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_shop_scheme/main.dart';
import 'widget_test.dart' show FakeAuthService;

void main() {
  testWidgets('password visibility and template account actions work',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: LoginPage(auth: FakeAuthService(), onSignedIn: () {})));
    await tester.pumpAndSettle();
    final signInEmailSize = tester.getSize(find.byType(TextFormField).first);
    final signInPasswordSize = tester.getSize(find.byType(TextFormField).last);
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).last)
            .controller!
            .text,
        isEmpty);
    await tester.enterText(find.byType(TextFormField).last, 'my-password');
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField).last).obscureText,
        isFalse);
    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField).last).obscureText,
        isTrue);
    expect(find.text('Reset'), findsNothing);
    await tester.ensureVisible(find.text('Forgot password?'));
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Forgot password'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    await tester.ensureVisible(find.text('Back to sign in'));
    await tester.tap(find.text('Back to sign in'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Register'));
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();
    expect(find.byType(RegistrationPage), findsOneWidget);
    expect(tester.getSize(find.byType(TextFormField).at(1)), signInEmailSize);
    expect(tester.getSize(find.byType(TextFormField).at(3)), signInPasswordSize);
    expect(find.byTooltip('Show password'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login fits a narrow screen with enlarged text and keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.5),
                viewInsets: const EdgeInsets.only(bottom: 240)),
            child: child!),
        home: LoginPage(auth: FakeAuthService(), onSignedIn: () {})));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
