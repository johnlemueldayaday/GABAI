import 'package:flutter/material.dart';
import 'package:gabay/config/app_theme.dart';
import 'package:gabay/widgets/home/tactile_button.dart';
import 'package:google_fonts/google_fonts.dart';

// Renders the add-to-list submit button in the add-item sheet.
class AddItemSubmitButton extends StatelessWidget {
  final bool hasText;
  final VoidCallback onTap;

  const AddItemSubmitButton({
    super.key,
    required this.hasText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TactileButton(
        onTap: hasText ? onTap : () {},
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            gradient: hasText
                ? LinearGradient(
                    colors: [kPrimary, kPrimaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: hasText ? null : kMuted.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            boxShadow: hasText
                ? [
                    BoxShadow(
                      color: kPrimary.withValues(alpha: 0.3),
                      offset: const Offset(0, 8),
                      blurRadius: 16,
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              'Add to List',
              style: GoogleFonts.plusJakartaSans(
                color: hasText ? Colors.white : kMuted,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
