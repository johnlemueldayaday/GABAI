import 'package:flutter/material.dart';
import 'package:gabay/models/grocery_models.dart';
import 'package:gabay/config/app_theme.dart';
import 'package:gabay/widgets/home/home_helpers.dart';
import 'package:gabay/widgets/home/tactile_button.dart';

// Renders a dismissible grocery item row with quantity and price controls.
class GroceryItemTile extends StatelessWidget {
  final GroceryItem item;
  final VoidCallback onToggle, onDelete;
  final void Function(int delta) onQtyChange;
  final VoidCallback onQtyEdit;
  final VoidCallback onPriceEdit;
  final VoidCallback onUnitEdit;
  final VoidCallback? onNameEdit;
  const GroceryItemTile({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onDelete,
    required this.onQtyChange,
    required this.onQtyEdit,
    required this.onPriceEdit,
    required this.onUnitEdit,
    this.onNameEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.startToEnd,
      onDismissed: (_) => onDelete(),
      background: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red.shade400),
            const SizedBox(width: 8),
            Text(
              'Remove',
              style: TextStyle(
                color: Colors.red.shade400,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: item.isDone ? 0.7 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [kShadowSoft],
          ),
          child: Column(
            children: [
              // ─── Top row: checkbox, name, total price ───
              Row(
                children: [
                  TactileButton(
                    onTap: onToggle,
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.elasticOut,
                      tween: Tween(begin: 1.0, end: item.isDone ? 1.15 : 1.0),
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: item.isDone ? kPrimary : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: item.isDone ? kPrimary : kBorder,
                                width: 2,
                              ),
                              boxShadow: item.isDone
                                  ? [
                                      BoxShadow(
                                        color: kPrimary.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : [],
                            ),
                            child: item.isDone
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 14,
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: GestureDetector(
                      onTap: onNameEdit,
                      child: Text(
                        item.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: kTextCharcoal,
                          decoration: item.isDone
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: kMuted,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    '₱${getItemTotal(item.price, item.qty, item.unit).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: item.isDone ? kMuted : kTextCharcoal,
                    ),
                  ),
                ],
              ),
              // ─── Bottom row: qty controls, unit price ───
              if (!item.isDone)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      const SizedBox(width: 38), // align with text above
                      // Quantity controls
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          QuantityStepButton(
                            onTap: () => onQtyChange(-1),
                            icon: Icons.remove,
                            semanticLabel: 'Decrease quantity',
                          ),
                          Semantics(
                            button: true,
                            label: 'Edit quantity, ${formatQty(item.qty)}',
                            child: TactileButton(
                              onTap: onQtyEdit,
                              child: SizedBox(
                                width: 52,
                                height: 44,
                                child: Center(
                                  child: Text(
                                    formatQty(item.qty),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: kTextCharcoal,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          QuantityStepButton(
                            onTap: () => onQtyChange(1),
                            icon: Icons.add,
                            semanticLabel: 'Increase quantity',
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onUnitEdit,
                        child: Text(
                          item.unit,
                          style: TextStyle(
                            fontSize: 12,
                            color: kMuted,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationStyle: TextDecorationStyle.dotted,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Tappable unit price
                      TactileButton(
                        onTap: onPriceEdit,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: kPrimary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                size: 12,
                                color: kPrimary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '₱${item.price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: kPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
