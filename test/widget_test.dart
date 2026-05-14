import 'package:flutter_test/flutter_test.dart';
import 'package:gabay/pages/cart.dart';

void main() {
  testWidgets('GroceryApp renders', (WidgetTester tester) async {
    await tester.pumpWidget(const GroceryApp());
    expect(find.text('GABAY'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
