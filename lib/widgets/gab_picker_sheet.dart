import 'package:flutter/material.dart';
import 'package:gabay/config/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// A single item in the [GabPickerSheet].
class GabPickerItem<T> {
  final T value;
  final String label;
  final Widget? leading;
  final String? subtitle;

  const GabPickerItem({
    required this.value,
    required this.label,
    this.leading,
    this.subtitle,
  });
}

/// Generic picker bottom sheet that matches the StorePickerSheet aesthetic.
///
/// Usage:
/// ```dart
/// final result = await showModalBottomSheet<GabPickerItem<String>>(
///   context: context,
///   isScrollControlled: true,
///   backgroundColor: Colors.transparent,
///   builder: (_) => GabPickerSheet<String>(
///     title: 'Select Category',
///     items: categories.map((c) => GabPickerItem(value: c, label: c)).toList(),
///     selectedValue: selectedCategory,
///     showSearch: true,
///   ),
/// );
/// if (result != null) setState(() => selectedCategory = result.value);
/// ```
class GabPickerSheet<T> extends StatefulWidget {
  final String title;
  final List<GabPickerItem<T>> items;
  final T? selectedValue;

  /// Show a search bar at the top.
  final bool showSearch;

  /// Hint text for the search bar.
  final String searchHint;

  /// If set, an "Add custom…" row is appended at the bottom; tapping it
  /// closes the sheet and returns `null` with [onAddCustom] fired.
  final String? addCustomLabel;
  final VoidCallback? onAddCustom;

  const GabPickerSheet({
    super.key,
    required this.title,
    required this.items,
    this.selectedValue,
    this.showSearch = false,
    this.searchHint = 'Search…',
    this.addCustomLabel,
    this.onAddCustom,
  });

  @override
  State<GabPickerSheet<T>> createState() => _GabPickerSheetState<T>();
}

class _GabPickerSheetState<T> extends State<GabPickerSheet<T>>
    with SingleTickerProviderStateMixin {
  String _query = '';
  final _searchCtrl = TextEditingController();
  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  List<GabPickerItem<T>> get _filtered {
    if (_query.isEmpty) return widget.items;
    return widget.items
        .where((it) => it.label.toLowerCase().contains(_query.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final hasCustom =
        widget.addCustomLabel != null && widget.onAddCustom != null;

    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ────────────────────────────────────────────────
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: kBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Header ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: kTextCharcoal,
                  ),
                ),
                Expanded(
                  child: Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: kTextCharcoal,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: kMuted),
                ),
              ],
            ),
          ),

          // ── Search bar ─────────────────────────────────────────────────
          if (widget.showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: kMutedBg.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.searchHint,
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: kMuted,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: kMuted,
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

          // ── List ───────────────────────────────────────────────────────
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.52,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                itemCount: filtered.length + (hasCustom ? 1 : 0),
                separatorBuilder: (_, _) =>
                    Divider(color: kBorder.withValues(alpha: 0.5), height: 1),
                itemBuilder: (context, index) {
                  // "Add custom" row at the bottom
                  if (hasCustom && index == filtered.length) {
                    return _buildAddCustomRow(context);
                  }

                  final item = filtered[index];
                  final isSelected = item.value == widget.selectedValue;

                  return _AnimatedRow(
                    index: index,
                    controller: _animCtrl,
                    child: ListTile(
                      onTap: () => Navigator.pop(context, item),
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: item.leading,
                      title: Text(
                        item.label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected ? kPrimary : kTextCharcoal,
                        ),
                      ),
                      subtitle: item.subtitle != null
                          ? Text(
                              item.subtitle!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: kMuted,
                              ),
                            )
                          : null,
                      trailing: isSelected
                          ? Icon(Icons.check_rounded, color: kPrimary, size: 20)
                          : Icon(
                              Icons.chevron_right_rounded,
                              color: kMuted,
                              size: 20,
                            ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Safe area padding
          SizedBox(height: 20 + MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildAddCustomRow(BuildContext context) {
    return ListTile(
      onTap: () {
        Navigator.pop(context);
        widget.onAddCustom?.call();
      },
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: kPrimary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.add_rounded, color: kPrimary, size: 20),
      ),
      title: Text(
        widget.addCustomLabel!,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: kPrimary,
        ),
      ),
    );
  }
}

/// Staggered fade + slide animation for each row.
class _AnimatedRow extends StatelessWidget {
  final int index;
  final AnimationController controller;
  final Widget child;

  const _AnimatedRow({
    required this.index,
    required this.controller,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final delay = (index * 0.05).clamp(0.0, 0.6);
    final start = delay;
    final end = (delay + 0.4).clamp(0.0, 1.0);

    final fade = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
    final slide = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: controller,
            curve: Interval(start, end, curve: Curves.easeOutCubic),
          ),
        );

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }
}

/// Convenience function — shows the sheet and returns the picked item or null.
Future<GabPickerItem<T>?> showGabPicker<T>({
  required BuildContext context,
  required String title,
  required List<GabPickerItem<T>> items,
  T? selectedValue,
  bool showSearch = false,
  String searchHint = 'Search…',
  String? addCustomLabel,
  VoidCallback? onAddCustom,
}) {
  return showModalBottomSheet<GabPickerItem<T>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => GabPickerSheet<T>(
      title: title,
      items: items,
      selectedValue: selectedValue,
      showSearch: showSearch,
      searchHint: searchHint,
      addCustomLabel: addCustomLabel,
      onAddCustom: onAddCustom,
    ),
  );
}
