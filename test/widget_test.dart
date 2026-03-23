import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_aismartwallet/pages/home.dart';

void main() {
  testWidgets('GroceryApp renders', (WidgetTester tester) async {
    await tester.pumpWidget(const GroceryApp());
    expect(find.text('Shopping'), findsOneWidget);
  });
}
