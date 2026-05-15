import 'package:flutter/material.dart';
import 'package:gabay/config/app_theme.dart';
import 'package:gabay/widgets/home/tactile_button.dart';
import 'package:google_fonts/google_fonts.dart';

// Renders the horizontal category selector for add-item suggestions.
class AddItemCategoryTabs extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelected;

  const AddItemCategoryTabs({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categories.length,
        separatorBuilder: (_, idx) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = categories[i];
          final selected = cat == selectedCategory;
          return TactileButton(
            onTap: () => onSelected(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? kPrimary : kMutedBg.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                cat,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? Colors.white : kMuted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
