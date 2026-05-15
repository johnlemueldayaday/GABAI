// Force IDE re-parse
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../pages/dashboard.dart';
import '../pages/cart.dart' show CartPage;
import '../pages/recent.dart';
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
            padding: const EdgeInsets.fromLTRB(24, 80, 24, 30),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 56),
                  child: Text(
                    'GABAY',
                    style: GoogleFonts.luckiestGuy(
                      fontSize: 48,
                      color: kTextCharcoal,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          offset: const Offset(4, 4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Image.asset(
                    'assets/images/navbaravatar.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
          _DrawerItem(
            icon: Icons.insights_rounded,
            label: 'Dashboard',
            isSelected: currentPage == 'Dashboard',
            onTap: () {
              Navigator.pop(context);
              if (currentPage != 'Dashboard') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const DashboardPage()),
                );
              }
            },
          ),
          _DrawerItem(
            icon: Icons.shopping_cart_outlined,
            label: 'Cart',
            isSelected: currentPage == 'Cart',
            onTap: () {
              Navigator.pop(context);
              if (currentPage != 'Cart') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const CartPage()),
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
        style: GoogleFonts.plusJakartaSans(
          color: isSelected ? kPrimary : kTextCharcoal,
          fontSize: 15,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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
