import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_shop_scheme/main.dart';
import 'package:mobile_shop_scheme/retail_design.dart';
import 'widget_test.dart' show FakeAuthService;

void main() {
  testWidgets('home promotion opens the published schemes tab', (tester) async {
    final auth = FakeAuthService()..email = 'customer@example.com';
    await tester.pumpWidget(MaterialApp(home: SessionGate(auth: auth)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore schemes'));
    await tester.pumpAndSettle();
    expect(find.text('The store has not published any schemes yet.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('benefit banner wraps at narrow width with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
      child: SingleChildScrollView(
          child: RetailBanner(
              eyebrow: 'Make more of your savings',
              title: 'Discover your shop benefit',
              description:
                  'Compare published plans and their eligible store benefits.',
              icon: Icons.redeem,
              coral: true,
              action: 'View plans & benefits',
              onTap: () {})),
    ))));
    expect(tester.takeException(), isNull);
  });
}
