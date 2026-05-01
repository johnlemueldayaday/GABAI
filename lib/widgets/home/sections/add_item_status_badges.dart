import 'package:flutter/material.dart';
import 'package:gabay/config/app_theme.dart';

// Renders the speech status or error row below the add-item search field.
class SpeechStatusIndicator extends StatelessWidget {
  final bool isListening;
  final String? errorText;

  const SpeechStatusIndicator({
    super.key,
    required this.isListening,
    required this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    if (!isListening && errorText == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isListening ? kPrimary : Colors.red.shade400,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isListening ? 'Listening... speak the item name' : errorText!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isListening ? kPrimary : Colors.red.shade400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Renders the badge shown when a typed grocery item is custom.
class CustomItemBadge extends StatelessWidget {
  final bool isVisible;

  const CustomItemBadge({super.key, required this.isVisible});

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: kPrimary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 14, color: kPrimary),
            const SizedBox(width: 6),
            Text(
              'New item — will be saved for future use',
              style: TextStyle(
                fontSize: 12,
                color: kPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
