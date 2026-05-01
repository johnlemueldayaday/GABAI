import 'package:flutter/material.dart';
import 'package:gabay/config/app_theme.dart';
import 'package:gabay/widgets/home/home_helpers.dart';
import 'package:gabay/widgets/home/tactile_button.dart';

// Renders the quantity, unit, and price controls in the add-item sheet.
class AddItemEntryControls extends StatelessWidget {
  final double qty;
  final String unit;
  final String priceText;
  final List<String> units;
  final VoidCallback onDecreaseQty;
  final VoidCallback onIncreaseQty;
  final ValueChanged<String> onUnitChanged;
  final VoidCallback onPriceTap;

  const AddItemEntryControls({
    super.key,
    required this.qty,
    required this.unit,
    required this.priceText,
    required this.units,
    required this.onDecreaseQty,
    required this.onIncreaseQty,
    required this.onUnitChanged,
    required this.onPriceTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FieldLabel('QTY'),
                const SizedBox(height: 8),
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: kBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorder),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: onDecreaseQty,
                        icon: Icon(
                          Icons.remove,
                          size: 16,
                          color: kTextCharcoal,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32),
                      ),
                      Expanded(
                        child: Text(
                          formatQty(qty),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: kTextCharcoal,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onIncreaseQty,
                        icon: Icon(Icons.add, size: 16, color: kTextCharcoal),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FieldLabel('UNIT'),
                const SizedBox(height: 8),
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: kBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: unit,
                      isExpanded: true,
                      icon: Icon(
                        Icons.keyboard_arrow_down,
                        size: 18,
                        color: kMuted,
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kTextCharcoal,
                      ),
                      onChanged: (v) {
                        if (v != null) onUnitChanged(v);
                      },
                      items: units
                          .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FieldLabel('PRICE (₱)'),
                const SizedBox(height: 8),
                TactileButton(
                  onTap: onPriceTap,
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: kBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kBorder),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        priceText.isEmpty ? '0.00' : priceText,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: priceText.isEmpty ? kMuted : kTextCharcoal,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Renders a small uppercase label for add-item entry fields.
class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: kMuted,
        letterSpacing: 1,
      ),
    );
  }
}
