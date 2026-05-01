import 'package:flutter/material.dart';
import 'package:gabay/config/app_theme.dart';

// Renders the centered empty-state message for an empty grocery list.
class EmptyListSection extends StatelessWidget {
  const EmptyListSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        builder: (context, value, child) {
          return Opacity(opacity: value, child: child);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: kMutedBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: 28,
                color: kMuted,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Your list is empty',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kTextCharcoal,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap + to add items',
              style: TextStyle(
                fontSize: 14,
                color: kMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
