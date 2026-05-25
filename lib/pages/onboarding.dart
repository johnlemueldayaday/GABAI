import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_theme.dart';
import '../models/finance_models.dart';
import '../services/finance_storage.dart';
import '../services/settings_service.dart';
import '../widgets/account_icon.dart';

// ─────────────────────────────────────────────────────────────
// Data model for wallet options
// ─────────────────────────────────────────────────────────────
class _WalletOption {
  final String name;
  final String category;
  final String assetPath;
  final int colorValue;

  const _WalletOption({
    required this.name,
    required this.category,
    required this.assetPath,
    required this.colorValue,
  });
}

const _allWallets = [
  _WalletOption(
    name: 'GCash',
    category: 'E-Wallet',
    assetPath: 'assets/images/gcash.png',
    colorValue: 0xFF007AFF,
  ),
  _WalletOption(
    name: 'Maya',
    category: 'E-Wallet',
    assetPath: 'assets/images/paymaya.png',
    colorValue: 0xFF6C22A6,
  ),
  _WalletOption(
    name: 'Cash',
    category: 'Cash',
    assetPath: 'assets/images/cash.png',
    colorValue: 0xFF10B981,
  ),
  _WalletOption(
    name: 'BDO',
    category: 'Bank',
    assetPath: 'assets/images/bdo.png',
    colorValue: 0xFF1D4ED8,
  ),
  _WalletOption(
    name: 'Landbank',
    category: 'Bank',
    assetPath: 'assets/images/landbank.png',
    colorValue: 0xFF15803D,
  ),
  _WalletOption(
    name: 'PSBank',
    category: 'Bank',
    assetPath: 'assets/images/psbank.png',
    colorValue: 0xFFB91C1C,
  ),
];

// ─────────────────────────────────────────────────────────────
// Entry widget — wraps the real app and overlays onboarding
// ─────────────────────────────────────────────────────────────
class OnboardingGate extends StatefulWidget {
  final Widget child;
  const OnboardingGate({super.key, required this.child});

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _done = SettingsService().onboardingComplete;
  }

  void _handleComplete() {
    setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;

    return Stack(
      children: [
        // Blurred real app behind
        IgnorePointer(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: widget.child,
          ),
        ),
        // Dark scrim
        Container(color: Colors.black.withValues(alpha: 0.45)),
        // Onboarding modal
        SafeArea(
          child: Center(child: OnboardingModal(onComplete: _handleComplete)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// The modal itself — 3 pages
// ─────────────────────────────────────────────────────────────
class OnboardingModal extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingModal({super.key, required this.onComplete});

  @override
  State<OnboardingModal> createState() => _OnboardingModalState();
}

class _OnboardingModalState extends State<OnboardingModal>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _page = 0;

  // Screen 1
  final _nameCtrl = TextEditingController();
  final Set<String> _selectedWallets = {};

  // Screen 2
  final _balanceCtrl = TextEditingController();
  String? _balanceTargetWallet;

  bool get _screen1Valid =>
      _nameCtrl.text.trim().isNotEmpty && _selectedWallets.isNotEmpty;

  // Animation
  late final AnimationController _bounceCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();
  late final Animation<double> _bounceAnim = CurvedAnimation(
    parent: _bounceCtrl,
    curve: Curves.easeOutBack,
  );

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    _bounceCtrl.dispose();
    super.dispose();
  }

  void _next() async {
    if (_page == 0) {
      // Validate
      if (!_screen1Valid) return;
      // Auto-select first wallet for balance target
      _balanceTargetWallet ??= _selectedWallets.first;
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
      setState(() => _page = 1);
    } else if (_page == 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
      setState(() => _page = 2);
    } else {
      await _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    // 1. Save user name
    await SettingsService().setUserName(_nameCtrl.text.trim());

    // 2. Create accounts from selected wallets
    for (final name in _selectedWallets) {
      final w = _allWallets.firstWhere((w) => w.name == name);
      final account = Account(
        id: '${DateTime.now().microsecondsSinceEpoch}$name',
        name: w.name,
        type: w.category,
        balance: 0.0,
        icon: w.assetPath,
        colorValue: w.colorValue,
      );
      await FinanceStorage.addAccount(account);
    }

    // 3. Set initial balance on the chosen wallet
    final amount = double.tryParse(_balanceCtrl.text.replaceAll(',', '')) ?? 0;
    if (amount > 0 && _balanceTargetWallet != null) {
      final accounts = await FinanceStorage.loadAccounts();
      final idx = accounts.indexWhere((a) => a.name == _balanceTargetWallet);
      if (idx != -1) {
        final updated = accounts[idx].copyWith(balance: amount);
        await FinanceStorage.updateAccount(updated);
        // Recalculate and persist net worth
        final allAccounts = await FinanceStorage.loadAccounts();
        final netWorth = allAccounts.fold(0.0, (s, a) => s + a.balance);
        await FinanceStorage.setNetWorth(netWorth);
      }
    }

    // 4. Mark onboarding as complete
    await SettingsService().setOnboardingComplete(true);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _bounceAnim,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 40,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress dots
              Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final active = i == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active ? kPrimary : kBorder,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),
              // Pages
              SizedBox(
                height: _pageHeight,
                child: PageView(
                  controller: _pageCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _Screen1(
                      nameCtrl: _nameCtrl,
                      selectedWallets: _selectedWallets,
                      onToggle: (name) => setState(() {
                        if (_selectedWallets.contains(name)) {
                          _selectedWallets.remove(name);
                        } else {
                          _selectedWallets.add(name);
                        }
                        // Reset target if removed
                        if (!_selectedWallets.contains(_balanceTargetWallet)) {
                          _balanceTargetWallet = _selectedWallets.isNotEmpty
                              ? _selectedWallets.first
                              : null;
                        }
                      }),
                      onNameChanged: () => setState(() {}),
                    ),
                    _Screen2(
                      balanceCtrl: _balanceCtrl,
                      selectedWallets: _selectedWallets.toList(),
                      targetWallet: _balanceTargetWallet,
                      onTargetChanged: (v) =>
                          setState(() => _balanceTargetWallet = v),
                    ),
                    const _Screen3(),
                  ],
                ),
              ),
              // Next / Get Started button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: (_page == 0 && !_screen1Valid) ? 0.4 : 1.0,
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (_page == 0 && !_screen1Valid) ? null : _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: kPrimary,
                        disabledForegroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _page == 2 ? 'Get Started 🎉' : 'Next →',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double get _pageHeight {
    switch (_page) {
      case 0:
        return 510;
      case 1:
        return 310;
      case 2:
        return 360;
      default:
        return 400;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Screen 1: Name + Wallet multi-select
// ─────────────────────────────────────────────────────────────
class _WalletOptionIcon extends StatelessWidget {
  final _WalletOption wallet;
  final double size;

  const _WalletOptionIcon({required this.wallet, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return AccountIconImage(
      name: wallet.name,
      icon: wallet.assetPath,
      size: size,
    );
  }
}

class _Screen1 extends StatelessWidget {
  final TextEditingController nameCtrl;
  final Set<String> selectedWallets;
  final void Function(String) onToggle;
  final VoidCallback onNameChanged;

  const _Screen1({
    required this.nameCtrl,
    required this.selectedWallets,
    required this.onToggle,
    required this.onNameChanged,
  });

  @override
  Widget build(BuildContext context) {
    const groups = [
      {
        'label': 'E-Wallet',
        'options': ['GCash', 'Maya'],
      },
      {
        'label': 'Cash',
        'options': ['Cash'],
      },
      {
        'label': 'Bank',
        'options': ['BDO', 'Landbank', 'PSBank'],
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Welcome!',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: kTextCharcoal,
                ),
              ),
              const SizedBox(width: 6),
              Image.asset(
                'assets/images/handwave.png',
                width: 31.2,
                height: 31.2,
                fit: BoxFit.contain,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Let\'s set up your wallet in under a minute.',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: kMuted),
          ),
          const SizedBox(height: 20),
          // Name field
          Text(
            'Your name',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: kMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: nameCtrl,
            onChanged: (_) => onNameChanged(),
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              color: kTextCharcoal,
            ),
            decoration: InputDecoration(
              hintText: 'John Lemuel',
              hintStyle: TextStyle(color: kMuted.withValues(alpha: 0.5)),
              filled: true,
              fillColor: kBackground,
              prefixIcon: Icon(Icons.person_outline_rounded, color: kMuted),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: kPrimary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Select your wallets',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: kMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          ...groups.map((g) {
            final label = g['label'] as String;
            final opts = g['options'] as List<String>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: kMuted.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: opts.map((name) {
                      final w = _allWallets.firstWhere((w) => w.name == name);
                      final selected = selectedWallets.contains(name);
                      final isCash = name == 'Cash';
                      return GestureDetector(
                        onTap: () => onToggle(name),
                        child: AnimatedScale(
                          scale: selected ? 0.95 : 1.0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutBack,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                            decoration: BoxDecoration(
                              borderRadius: isCash ? BorderRadius.circular(12) : BorderRadius.zero,
                              border: !isCash
                                  ? Border.all(
                                      color: selected
                                          ? kPrimary
                                          : Colors.grey.withValues(alpha: 0.25),
                                      width: 2.0,
                                    )
                                  : null,
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: kPrimary.withValues(alpha: 0.4),
                                        blurRadius: 14,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 4),
                                      )
                                    ]
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      )
                                    ],
                            ),
                            child: _WalletOptionIcon(wallet: w, size: 45),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Screen 2: Initial balance
// ─────────────────────────────────────────────────────────────
class _Screen2 extends StatelessWidget {
  final TextEditingController balanceCtrl;
  final List<String> selectedWallets;
  final String? targetWallet;
  final void Function(String?) onTargetChanged;

  const _Screen2({
    required this.balanceCtrl,
    required this.selectedWallets,
    required this.targetWallet,
    required this.onTargetChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Initial Balance 💰',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: kTextCharcoal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Optionally enter your current balance.',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: kMuted),
          ),
          const SizedBox(height: 24),
          Text(
            'How much is your total balance right now?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: kMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: balanceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
            ],
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: kTextCharcoal,
            ),
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: TextStyle(color: kMuted.withValues(alpha: 0.4)),
              prefixText: '₱ ',
              prefixStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: kTextCharcoal,
              ),
              filled: true,
              fillColor: kBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: kPrimary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Which wallet should this apply to?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: kMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: kBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: DropdownButtonFormField<String>(
              initialValue: targetWallet,
              dropdownColor: kCardBg,
              borderRadius: BorderRadius.circular(16),
              elevation: 8,
              menuMaxHeight: 280,
              style: GoogleFonts.plusJakartaSans(
                color: kTextCharcoal,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              items: selectedWallets.map((name) {
                final w = _allWallets.firstWhere((w) => w.name == name);
                return DropdownMenuItem(
                  value: name,
                  child: Row(
                    children: [
                      _WalletOptionIcon(wallet: w, size: 20),
                      const SizedBox(width: 8),
                      Text(name),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onTargetChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Screen 3: Walkthrough tour
// ─────────────────────────────────────────────────────────────
class _Screen3 extends StatelessWidget {
  const _Screen3();

  @override
  Widget build(BuildContext context) {
    const features = [
      _FeatureItem(
        icon: Icons.dashboard_rounded,
        color: 0xFF10B981,
        title: 'Dashboard',
        desc: 'See your total balance, recent income & expenses at a glance.',
      ),
      _FeatureItem(
        icon: Icons.account_balance_wallet_rounded,
        color: 0xFF6366F1,
        title: 'Wallet',
        desc: 'Manage all your accounts, log transactions & transfer funds.',
      ),
      _FeatureItem(
        icon: Icons.calendar_month_rounded,
        color: 0xFFF59E0B,
        title: 'Calendar',
        desc: 'Schedule and track recurring bills, income, and due dates.',
      ),
      _FeatureItem(
        icon: Icons.shopping_cart_rounded,
        color: 0xFFEC4899,
        title: 'Grocery',
        desc: 'Plan grocery lists and track how much you spend per trip.',
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You\'re all set! ✨',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: kTextCharcoal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Here\'s a quick look at what you can do.',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: kMuted),
          ),
          const SizedBox(height: 20),
          ...features.map((f) => _FeatureTile(item: f)),
        ],
      ),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final int color;
  final String title;
  final String desc;
  const _FeatureItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
  });
}

class _FeatureTile extends StatelessWidget {
  final _FeatureItem item;
  const _FeatureTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Color(item.color).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: Color(item.color), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: kTextCharcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.desc,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: kMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
