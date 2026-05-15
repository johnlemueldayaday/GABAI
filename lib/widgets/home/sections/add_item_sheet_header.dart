import 'package:flutter/material.dart';
import 'package:gabay/config/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

// Renders the add-item sheet title and close button.
class AddItemSheetHeader extends StatelessWidget {
  final VoidCallback onClose;

  const AddItemSheetHeader({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
      child: Row(
        children: [
          Text(
            'Add Item',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: kTextCharcoal,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: kMutedBg.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close_rounded, size: 17, color: kMuted),
            ),
          ),
        ],
      ),
    );
  }
}
