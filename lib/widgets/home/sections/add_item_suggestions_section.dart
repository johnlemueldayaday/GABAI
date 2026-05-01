import 'package:flutter/material.dart';
import 'package:gabay/config/app_theme.dart';
import 'package:gabay/widgets/home/tactile_button.dart';
import 'package:gabay/widgets/home/sections/spring_curve.dart';

// Renders the add-item suggestion chips for the selected category and search text.
class AddItemSuggestionsSection extends StatelessWidget {
  final List<Map<String, dynamic>> suggestions;
  final ValueChanged<Map<String, dynamic>> onSuggestionTap;

  const AddItemSuggestionsSection({
    super.key,
    required this.suggestions,
    required this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'SUGGESTIONS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: kMuted,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: suggestions.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No suggestions found',
                    style: TextStyle(
                      fontSize: 13,
                      color: kMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(suggestions.length, (index) {
                    final item = suggestions[index];
                    return StaggeredPop(
                      delay: index * 20,
                      child: TactileButton(
                        onTap: () => onSuggestionTap(item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: kBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, size: 14, color: kMuted),
                              const SizedBox(width: 4),
                              Text(
                                item['name'],
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: kTextCharcoal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
        ),
      ],
    );
  }
}
