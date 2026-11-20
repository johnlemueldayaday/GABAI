import 'package:flutter/material.dart';
import 'package:gabay/models/grocery_models.dart';
import 'package:gabay/config/app_theme.dart';
import 'package:gabay/widgets/home/sections/grocery_item_tile.dart';

// Renders a titled sliver list of grocery item tiles.
class GroceryListSection extends StatelessWidget {
  final String title;
  final List<GroceryItem> items;
  final EdgeInsets titlePadding;
  final void Function(GroceryItem item) onToggle;
  final void Function(GroceryItem item) onDelete;
  final void Function(GroceryItem item, int delta) onQtyChange;
  final void Function(GroceryItem item) onQtyEdit;
  final void Function(GroceryItem item) onPriceEdit;
  final void Function(GroceryItem item) onUnitEdit;
  final void Function(GroceryItem item)? onNameEdit;

  const GroceryListSection({
    super.key,
    required this.title,
    required this.items,
    required this.titlePadding,
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
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: titlePadding,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kMuted,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final item = items[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GroceryItemTile(
                item: item,
                onToggle: () => onToggle(item),
                onDelete: () => onDelete(item),
                onQtyChange: (delta) => onQtyChange(item, delta),
                onQtyEdit: () => onQtyEdit(item),
                onPriceEdit: () => onPriceEdit(item),
                onUnitEdit: () => onUnitEdit(item),
                onNameEdit: onNameEdit == null ? null : () => onNameEdit!(item),
              ),
            );
          }, childCount: items.length),
        ),
      ],
    );
  }
}
