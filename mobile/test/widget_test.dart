import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_shop_scheme/main.dart';

void main() {
  testWidgets('shows the authentication entry point', (tester) async {
    await tester.pumpWidget(const SchemeApp());
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
  });
}
