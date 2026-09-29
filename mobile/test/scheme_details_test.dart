import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_shop_scheme/main.dart';

void main() {
  testWidgets('scheme details opens without a random bound error on web', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SchemeDetails(
      auth: AuthService(),
      scheme: {
        'id': 'test-scheme', 'name': 'Test scheme', 'version': 1,
        'monthly_amount_paise': 50000, 'installment_count': 11,
        'benefit_paise': 50000,
        'policy': {
          'terms_text': 'Test terms', 'grace_days': 7,
          'late_payments_allowed': true, 'advance_payments_allowed': false,
          'redemption_valid_days': 365, 'cancellation_allowed': true,
          'refund_deduction_paise': 0, 'due_rule': 'ANNIVERSARY',
        },
      },
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Test scheme'), findsOneWidget);
  });
}
