import 'package:flutter/material.dart';
import 'package:gabay/config/app_theme.dart';

// Renders the add-item search field with microphone control.
class AddItemSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onToggleListening;
  final bool isListening;
  final Animation<double> micPulseScale;

  const AddItemSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onToggleListening,
    required this.isListening,
    required this.micPulseScale,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: kBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
          boxShadow: isListening
              ? [
                  BoxShadow(
                    color: kPrimary.withValues(alpha: 0.16),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: kTextCharcoal,
          ),
          decoration: InputDecoration(
            hintText: 'Search or type a new item...',
            hintStyle: TextStyle(color: kMuted, fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: kMuted, size: 20),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Center(
                child: ScaleTransition(
                  scale: micPulseScale,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onToggleListening,
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isListening
                              ? kPrimary.withValues(alpha: 0.12)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isListening
                              ? Icons.graphic_eq_rounded
                              : Icons.mic_none_rounded,
                          size: 19,
                          color: isListening ? kPrimary : kMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }
}
