import 'package:flutter/material.dart';
import 'package:gabay/config/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class StorePickerSheet extends StatefulWidget {
  final List<String> recentStores;
  final Function(String) onStoreSelected;

  const StorePickerSheet({
    super.key,
    required this.recentStores,
    required this.onStoreSelected,
  });

  @override
  State<StorePickerSheet> createState() => _StorePickerSheetState();
}

class _StorePickerSheetState extends State<StorePickerSheet> {
  bool _showRecent = true;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  final List<String> _allStores = [
    'Puregold',
    'SM Supermarket',
    'Robinsons Supermarket',
    'Savemore',
    'Public Market',
    '7-Eleven',
    'Ministop',
    'S&R Membership Shopping',
    'Landers Superstore',
    'MerryMart',
    'Shopwise',
    'WalterMart',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<String> stores = _showRecent ? widget.recentStores : _allStores;
    
    if (_searchQuery.isNotEmpty) {
      stores = stores
          .where((s) => s.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Maya-style Header
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: kTextCharcoal),
                ),
                Expanded(
                  child: Text(
                    'Select Store',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
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

          // Search Bar (Maya Aesthetic)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: kMutedBg.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Search for a store',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    color: kMuted,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: Icon(Icons.search_rounded, color: kMuted, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          
          // Toggle (Maya Aesthetic - thinner, less bold)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                _TabItem(
                  label: 'Recent',
                  isActive: _showRecent,
                  onTap: () => setState(() => _showRecent = true),
                ),
                const SizedBox(width: 12),
                _TabItem(
                  label: 'All',
                  isActive: !_showRecent,
                  onTap: () => setState(() => _showRecent = false),
                ),
              ],
            ),
          ),

          // Store List
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: stores.length + 1,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                separatorBuilder: (context, idx) => Divider(color: kBorder.withValues(alpha: 0.5), height: 1),
                itemBuilder: (context, index) {
                  if (index == stores.length) {
                    return ListTile(
                      onTap: () => _showAddNewStoreDialog(context),
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
                        'Add new store...',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: kPrimary,
                        ),
                      ),
                    );
                  }
                  
                  final store = stores[index];
                  return ListTile(
                    onTap: () {
                      widget.onStoreSelected(store);
                      Navigator.pop(context);
                    },
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    title: Text(
                      store,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: kTextCharcoal,
                      ),
                    ),
                    trailing: Icon(Icons.chevron_right_rounded, color: kMuted, size: 20),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  void _showAddNewStoreDialog(BuildContext context) async {
    final nav = Navigator.of(context);
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add New Store',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: kTextCharcoal,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Store name',
                hintStyle: TextStyle(color: kMuted),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: kBorder)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: kPrimary, width: 2)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: kMuted, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: Text('Add', style: TextStyle(color: kPrimary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      widget.onStoreSelected(result);
      nav.pop();
    }
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabItem({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? kPrimary : kMuted,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 20,
            height: 2,
            decoration: BoxDecoration(
              color: isActive ? kPrimary : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
