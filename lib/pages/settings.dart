import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gabay/config/app_theme.dart';
import 'package:gabay/services/settings_service.dart';
import 'package:gabay/services/notification_service.dart';
import 'package:gabay/services/grocery_storage.dart';
import 'package:gabay/services/bill_storage.dart';
import 'package:gabay/services/price_storage.dart';
import 'package:gabay/services/finance_storage.dart';
import 'package:gabay/services/future_event_storage.dart';
import 'package:gabay/pages/splash_screen.dart';
import 'package:gabay/navigation/app_routes.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _settings = SettingsService();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: kBackground,
          appBar: AppBar(
            backgroundColor: kBackground,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: kTextCharcoal,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Settings',
              style: GoogleFonts.plusJakartaSans(
                color: kTextCharcoal,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              // ─── Appearance ──────────────────────────────────────────
              _SectionHeader(title: 'Appearance', icon: Icons.palette_outlined),
              _SettingsCard(
                children: [
                  _ThemeTile(
                    label: 'Light Mode',
                    icon: Icons.light_mode_outlined,
                    selected: _settings.themeMode == ThemeMode.light,
                    onTap: () => _settings.setThemeMode(ThemeMode.light),
                  ),
                  _Divider(),
                  _ThemeTile(
                    label: 'Dark Mode',
                    icon: Icons.dark_mode_outlined,
                    selected: _settings.themeMode == ThemeMode.dark,
                    onTap: () => _settings.setThemeMode(ThemeMode.dark),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ─── Currency ────────────────────────────────────────────
              _SectionHeader(
                title: 'Currency',
                icon: Icons.attach_money_rounded,
              ),
              _SettingsCard(
                children: [
                  _CurrencyDropdownTile(
                    selected: _settings.currency,
                    onChanged: _settings.setCurrency,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ─── Notifications & Behavior ────────────────────────────
              _SectionHeader(title: 'Behavior', icon: Icons.tune_rounded),
              _SettingsCard(
                children: [
                  _SwitchTile(
                    icon: Icons.notifications_outlined,
                    label: 'Budget Alerts',
                    subtitle: 'Warn when you exceed your budget',
                    value: _settings.budgetAlerts,
                    onChanged: _settings.setBudgetAlerts,
                  ),
                  _Divider(),
                  _SwitchTile(
                    icon: Icons.auto_awesome_outlined,
                    label: 'Smart Suggestions',
                    subtitle: 'AI-powered item recommendations',
                    value: _settings.smartSuggestions,
                    onChanged: _settings.setSmartSuggestions,
                  ),
                  _Divider(),
                  _SwitchTile(
                    icon: Icons.view_agenda_outlined,
                    label: 'Compact View',
                    subtitle: 'Smaller item cards in shopping list',
                    value: _settings.compactView,
                    onChanged: _settings.setCompactView,
                  ),
                  _Divider(),
                  _SwitchTile(
                    icon: Icons.lightbulb_outline_rounded,
                    label: 'Savings Tips',
                    subtitle: 'Show money-saving tips on the home screen',
                    value: _settings.showSavingsTips,
                    onChanged: _settings.setShowSavingsTips,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ─── Widgets & Integrations ───────────────────────────────
              _SectionHeader(title: 'Widgets', icon: Icons.widgets_outlined),
              _SettingsCard(
                children: [
                  _ActionTile(
                    icon: Icons.add_to_home_screen_outlined,
                    label: 'Lock Screen Widgets',
                    subtitle: 'Learn how to add widgets to your lock screen',
                    iconColor: kPrimary,
                    onTap: () {
                      _showWidgetHowToDialog(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ─── System Notifications ─────────────────────────────────
              _SectionHeader(
                title: 'Notifications & Alerts',
                icon: Icons.notifications_active_outlined,
              ),
              _SettingsCard(
                children: [
                  _ActionTile(
                    icon: Icons.notifications_outlined,
                    label: 'Send Test Notification',
                    subtitle: 'Test immediate or 3s delayed banner outside app',
                    iconColor: kPrimary,
                    onTap: () => _showTestNotificationSheet(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ─── Data & Privacy ───────────────────────────────────────
              _SectionHeader(title: 'Data', icon: Icons.storage_outlined),
              _SettingsCard(
                children: [
                  _ActionTile(
                    icon: Icons.delete_sweep_outlined,
                    label: 'Reset All Data',
                    subtitle:
                        'Clear all data including accounts, transactions, bills, and settings',
                    iconColor: kTextCharcoal,
                    onTap: () => _confirmAction(
                      context,
                      title: 'Reset All Data?',
                      message:
                          'This will permanently delete all your accounts, transactions, bills, shopping lists, and settings. You will need to set up your wallet again.',
                      confirmLabel: 'Reset All',
                      confirmColor: Colors.red.shade600,
                      onConfirm: () async {
                        // Clear all data from storage services
                        await GroceryStorage.clear();
                        await BillStorage.clear();
                        await PriceStorage.clear();
                        await FinanceStorage.clear();
                        await FutureEventStorage.clear();

                        // Reset settings (this also clears onboarding flag)
                        await _settings.resetAll();

                        if (context.mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              settings: const RouteSettings(
                                name: kSplashRouteName,
                              ),
                              builder: (_) => const SplashScreen(),
                            ),
                            (route) => false,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ─── About ────────────────────────────────────────────────
              _SectionHeader(title: 'About', icon: Icons.info_outline_rounded),
              _SettingsCard(
                children: [
                  _InfoTile(label: 'App Name', value: 'GABAI'),
                  _Divider(),
                  _InfoTile(label: 'Version', value: '1.42'),
                ],
              ),
              const SizedBox(height: 8),

              // ─── Reset Settings ───────────────────────────────────────
              GestureDetector(
                onTap: () => _confirmAction(
                  context,
                  title: 'Reset Settings?',
                  message:
                      'All preferences (currency, theme, toggles) will be restored to defaults.',
                  confirmLabel: 'Reset',
                  confirmColor: kPrimary,
                  onConfirm: () async {
                    await _settings.resetAll();
                    if (context.mounted) {
                      _showSnack(context, '✅ Settings restored to defaults');
                    }
                  },
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kBorder),
                    color: kCardBg,
                  ),
                  child: Center(
                    child: Text(
                      'Reset Settings to Defaults',
                      style: TextStyle(
                        color: kMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showWidgetHowToDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Lock Screen Widgets',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: kTextCharcoal,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To add widgets to your Lock Screen:',
              style: TextStyle(color: kTextCharcoal, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              '1. Long-press on your Lock Screen\n'
              '2. Tap "Customize" then "Lock Screen"\n'
              '3. Tap "Add Widgets"\n'
              '4. Find GABAI and select your desired widget',
              style: TextStyle(color: kMuted, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it',
              style: TextStyle(color: kPrimary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showTestNotificationSheet(BuildContext context) {
    bool delay3s = true;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Test System Notifications',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kTextCharcoal,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Trigger a real OS banner. Turn on delay to lock your device or switch to another app first.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: kMuted,
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: kPrimary,
                  title: Text(
                    '3-Second Delay',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kTextCharcoal,
                    ),
                  ),
                  subtitle: Text(
                    'Gives you time to lock or background the app',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: kMuted,
                    ),
                  ),
                  value: delay3s,
                  onChanged: (val) => setSheetState(() => delay3s = val),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final hasPerm = await NotificationService()
                          .requestNotificationPermissions(context: context);
                      if (!hasPerm) return;

                      if (delay3s && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Banner firing in 3s! Swipe to home screen or lock device now.',
                            ),
                            duration: Duration(seconds: 3),
                          ),
                        );
                        await Future.delayed(const Duration(seconds: 3));
                      }

                      await NotificationService().notifyTransaction(
                        type: 'EXPENSE',
                        amount: 99.00,
                        accountName: 'GCash',
                        newBalance: 250.60,
                        accountId: 'gcash_test',
                      );
                    },
                    child: Text(
                      'Fire Expense Banner (₱99.00 from GCash)',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kPrimary,
                      side: BorderSide(color: kPrimary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final hasPerm = await NotificationService()
                          .requestNotificationPermissions(context: context);
                      if (!hasPerm) return;

                      if (delay3s && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Banner firing in 3s! Swipe to home screen or lock device now.',
                            ),
                            duration: Duration(seconds: 3),
                          ),
                        );
                        await Future.delayed(const Duration(seconds: 3));
                      }

                      await NotificationService().notifyTransaction(
                        type: 'INCOME',
                        amount: 5000.00,
                        accountName: 'BPI',
                        newBalance: 18786.00,
                        description: 'Freelance Project',
                        accountId: 'bpi_test',
                      );
                    },
                    child: Text(
                      'Fire Income Banner (₱5,000.00 from Freelance)',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
    required VoidCallback onConfirm,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: anim1.value,
          child: Opacity(
            opacity: anim1.value,
            child: AlertDialog(
              backgroundColor: kCardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: confirmColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      confirmLabel.toLowerCase().contains('clear')
                          ? Icons.auto_delete_outlined
                          : Icons.warning_amber_rounded,
                      size: 36,
                      color: confirmColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: kTextCharcoal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: kMuted,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: kBorder),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              color: kMuted,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            onConfirm();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: confirmColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            confirmLabel,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
        backgroundColor: kTextCharcoal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 14, color: kPrimary),
          const SizedBox(width: 6),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: kPrimary,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Settings Card Container ──────────────────────────────────────────────────
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [kShadowSoft],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: children),
      ),
    );
  }
}

// ─── Divider ──────────────────────────────────────────────────────────────────
class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: kBorder,
      indent: 16,
      endIndent: 16,
    );
  }
}

// ─── Theme Tile ───────────────────────────────────────────────────────────────
class _ThemeTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: selected
                    ? kPrimary.withValues(alpha: 0.12)
                    : kBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: selected ? kPrimary : kMuted),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? kTextCharcoal : kMuted,
                ),
              ),
            ),
            if (selected)
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: kPrimary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 12),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Currency Tile ────────────────────────────────────────────────────────────
// ─── Currency Dropdown Tile ───────────────────────────────────────────────────
class _CurrencyDropdownTile extends StatelessWidget {
  final String selected;
  final Future<void> Function(String) onChanged;
  const _CurrencyDropdownTile({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedEntry = SettingsService.availableCurrencies.firstWhere(
      (c) => c['symbol'] == selected,
      orElse: () => SettingsService.availableCurrencies.first,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Icon badge
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                selected,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: kPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Label + selected name — flexible so it never pushes dropdown
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Currency',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kTextCharcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  selectedEntry['name']!,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: kMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Compact dropdown — shows only the symbol in the button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: kBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selected,
                isDense: true,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: kMuted,
                ),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kTextCharcoal,
                ),
                onChanged: (val) {
                  if (val != null) onChanged(val);
                },
                // Button label: just the symbol
                selectedItemBuilder: (context) {
                  return SettingsService.availableCurrencies.map((c) {
                    return Center(
                      child: Text(
                        c['symbol']!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kTextCharcoal,
                        ),
                      ),
                    );
                  }).toList();
                },
                // Menu items: symbol only
                items: SettingsService.availableCurrencies.map((c) {
                  return DropdownMenuItem<String>(
                    value: c['symbol'],
                    child: Text(
                      c['symbol']!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: kPrimary,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Switch Tile ──────────────────────────────────────────────────────────────
class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final Future<void> Function(bool) onChanged;
  const _SwitchTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: value ? kPrimary.withValues(alpha: 0.12) : kBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: value ? kPrimary : kMuted),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kTextCharcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: kMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: kPrimary,
          ),
        ],
      ),
    );
  }
}

// ─── Action Tile ──────────────────────────────────────────────────────────────
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color iconColor;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kTextCharcoal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: kMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: kMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Info Tile ────────────────────────────────────────────────────────────────
class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: kMuted,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kTextCharcoal,
            ),
          ),
        ],
      ),
    );
  }
}
