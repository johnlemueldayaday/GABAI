import 'package:flutter/material.dart';
import 'package:gabay/config/app_theme.dart';

// Renders the add-item sheet title and close button.
class AddItemSheetHeader extends StatelessWidget {
  final VoidCallback onClose;

  const AddItemSheetHeader({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          Text(
            'Add Item',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: kTextCharcoal,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: kMutedBg,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(Icons.close, size: 16, color: kMuted),
            ),
          ),
        ],
      ),
    );
  }
}
