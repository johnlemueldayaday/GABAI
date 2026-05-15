import 'package:flutter/material.dart';
import 'package:gabay/config/app_theme.dart';
import 'package:gabay/widgets/home/tactile_button.dart';

// Renders the shopping list title row and finish action.
class ShoppingHeaderSection extends StatelessWidget {
  final String listName;
  final VoidCallback onEditListName;
  final VoidCallback onFinishList;
  final VoidCallback onClearAll;
  final VoidCallback onDeleteList;

  const ShoppingHeaderSection({
    super.key,
    required this.listName,
    required this.onEditListName,
    required this.onFinishList,
    required this.onClearAll,
    required this.onDeleteList,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CART',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: kMuted,
                letterSpacing: 2.0,
              ),
            ),
            Row(
              children: [
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: kMuted, size: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: kBackground,
                  surfaceTintColor: Colors.transparent,
                  offset: const Offset(0, 40),
                  onSelected: (value) {
                    if (value == 'clear') {
                      onClearAll();
                    } else if (value == 'delete') {
                      onDeleteList();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'clear',
                      child: Row(
                        children: [
                          Icon(Icons.remove_shopping_cart_outlined, size: 18, color: kTextCharcoal),
                          const SizedBox(width: 8),
                          Text(
                            'Clear Items',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: kTextCharcoal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(
                            'Delete Cart',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                TactileButton(
                  onTap: onFinishList,
                  child: Container(
                    decoration: BoxDecoration(
                      color: kPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 16,
                            color: kPrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Finish',
                            style: TextStyle(
                              color: kPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onEditListName,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  listName,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: kTextCharcoal,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.edit_outlined, size: 20, color: kMuted),
            ],
          ),
        ),
      ],
    );
  }
}
