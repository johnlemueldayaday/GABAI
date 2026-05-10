// Force IDE re-parse
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../pages/home.dart';
import '../pages/recent.dart';
import '../pages/analytics.dart';
import '../pages/settings.dart';
import '../pages/bills.dart';
import '../pages/ramsey_chat.dart';
import '../config/app_theme.dart';

class AppDrawer extends StatelessWidget {
  final String currentPage;

  const AppDrawer({super.key, required this.currentPage});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: kBackground,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 80, 24, 20),
            decoration: BoxDecoration(color: kBackground),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                Text(
                  'GABAY',
                  style: GoogleFonts.bangers(
                    textStyle: TextStyle(
                      color: kTextCharcoal,
                      fontSize: 40,
                      fontVariations: const [
                        FontVariation('ital', 0),
                        FontVariation('wght', 400),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _DrawerItem(
            icon: Icons.shopping_cart_outlined,
            label: 'Shopping',
            isSelected: currentPage == 'Shopping',
            onTap: () {
              Navigator.pop(context);
              if (currentPage != 'Shopping') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomePage()),
                );
              }
            },
          ),
          _DrawerItem(
            icon: Icons.history,
            label: 'Recent Groceries',
            isSelected: currentPage == 'Recent',
            onTap: () {
              Navigator.pop(context);
              if (currentPage != 'Recent') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const RecentPage()),
                );
              }
            },
          ),
          _DrawerItem(
            icon: Icons.insights_rounded,
            label: 'Insights',
            isSelected: currentPage == 'Insights',
            onTap: () {
              Navigator.pop(context);
              if (currentPage != 'Insights') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const AnalyticsPage()),
                );
              }
            },
          ),
          _DrawerItem(
            icon: Icons.receipt_long_rounded,
            label: 'Bills Tracker',
            isSelected: currentPage == 'Bills',
            onTap: () {
              Navigator.pop(context);
              if (currentPage != 'Bills') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const BillsPage()),
                );
              }
            },
          ),
          _DrawerItem(
            icon: Icons.restaurant_menu_rounded,
            label: 'Ramsey',
            isSelected: currentPage == 'Ramsey',
            onTap: () {
              Navigator.pop(context);
              if (currentPage != 'Ramsey') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const RamseyChatPage()),
                );
              }
            },
          ),
          // ─── Spacer pushes Settings to the bottom ───────────────────
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Divider(
              color: kBorder,
              thickness: 1,
              indent: 24,
              endIndent: 24,
            ),
          ),
          _DrawerItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            isSelected: currentPage == 'Settings',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? kPrimary : kTextCharcoal),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? kPrimary : kTextCharcoal,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
      onTap: onTap,
      selected: isSelected,
      selectedTileColor: kPrimary.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }
}
