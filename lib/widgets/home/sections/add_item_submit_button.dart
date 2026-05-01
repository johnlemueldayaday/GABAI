import 'package:flutter/material.dart';
import 'package:gabay/config/app_theme.dart';
import 'package:gabay/widgets/home/tactile_button.dart';

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
          height: 52,
          decoration: BoxDecoration(
            gradient: hasText
                ? LinearGradient(
                    colors: [kPrimary, kPrimaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: hasText ? null : kMutedBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: hasText
                ? [
                    BoxShadow(
                      color: kPrimary.withValues(alpha: 0.25),
                      offset: const Offset(0, 6),
                      blurRadius: 12,
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              'Add to List',
              style: TextStyle(
                color: hasText ? Colors.white : kMuted,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
