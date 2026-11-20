import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gabay/models/grocery_models.dart';
import 'package:gabay/widgets/home/home_helpers.dart';
import 'package:gabay/widgets/home/sections/grocery_item_tile.dart';
import 'package:gabay/widgets/home/sections/numeric_keypad_sheet.dart';

void main() {
  test('manual quantities follow the current unit step rules', () {
    expect(isValidQty(0.125, 'kg'), isTrue);
    expect(isValidQty(0.75, 'kg'), isTrue);
    expect(isValidQty(5, 'kg'), isTrue);
    expect(isValidQty(6, 'kg'), isTrue);
    expect(isValidQty(0.333, 'kg'), isFalse);
    expect(isValidQty(1.251, 'kg'), isFalse);
    expect(isValidQty(5.5, 'kg'), isFalse);

    expect(isValidQty(1, 'pcs'), isTrue);
    expect(isValidQty(999, 'pcs'), isTrue);
    expect(isValidQty(0.5, 'pcs'), isFalse);
    expect(isValidQty(1000, 'pcs'), isFalse);
  });

  testWidgets('tapping the quantity opens its edit callback', (tester) async {
    var editOpened = false;
    final item = GroceryItem(
      id: 'item-1',
      name: 'Flour',
      qty: 1,
      unit: 'kg',
      price: 10,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroceryItemTile(
            item: item,
            onToggle: () {},
            onDelete: () {},
            onQtyChange: (_) {},
            onQtyEdit: () => editOpened = true,
            onPriceEdit: () {},
            onUnitEdit: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('1'));
    expect(editOpened, isTrue);
  });

  testWidgets('quantity keypad accepts kg three-decimal steps', (tester) async {
    double? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showModalBottomSheet<double>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const NumericKeypadSheet(
                    initialValue: 1,
                    itemName: 'Flour',
                    quantityUnit: 'kg',
                  ),
                );
              },
              child: const Text('Open quantity'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open quantity'));
    await tester.pumpAndSettle();

    Finder keypadKey(String label) => find.byWidgetPredicate(
      (widget) => widget is KeypadButton && widget.label == label,
    );

    await tester.tap(keypadKey('.'));
    await tester.tap(keypadKey('1'));
    await tester.tap(keypadKey('2'));
    await tester.tap(keypadKey('5'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Confirm'));
    await tester.pumpAndSettle();

    expect(result, 0.125);
  });

  testWidgets('quantity keypad blocks values outside unit limits', (
    tester,
  ) async {
    double? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showModalBottomSheet<double>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const NumericKeypadSheet(
                    initialValue: 1,
                    itemName: 'Apples',
                    quantityUnit: 'pcs',
                  ),
                );
              },
              child: const Text('Open quantity'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open quantity'));
    await tester.pumpAndSettle();

    Finder keypadKey(String label) => find.byWidgetPredicate(
      (widget) => widget is KeypadButton && widget.label == label,
    );

    await tester.tap(keypadKey('.'));
    await tester.tap(keypadKey('5'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a whole quantity from 1 to 999.'), findsOneWidget);

    final confirmText = find.textContaining('Confirm');
    final confirmPointer = find.ancestor(
      of: confirmText,
      matching: find.byType(IgnorePointer),
    );
    expect(
      tester.widgetList<IgnorePointer>(confirmPointer).any(
        (pointer) => pointer.ignoring,
      ),
      isTrue,
    );
    expect(find.text('Edit Quantity'), findsOneWidget);
    expect(result, isNull);
  });
}
