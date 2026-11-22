import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_theme.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import 'wallet.dart';

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

  final _nameCtrl = TextEditingController();

  bool get _screen1Valid => _nameCtrl.text.trim().isNotEmpty;

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
    _bounceCtrl.dispose();
    super.dispose();
  }

  void _next() async {
    if (_page == 0) {
      if (!_screen1Valid) return;
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
      setState(() => _page = 1);
    } else {
      await _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    await SettingsService().setUserName(_nameCtrl.text.trim());
    await SettingsService().setOnboardingComplete(true);
    if (mounted && !kIsWeb) {
      await NotificationService().requestNotificationPermissions(
        context: context,
      );
    }
    widget.onComplete();
    if (mounted) {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => const WalletPage(openAddWalletOnStart: true),
        ),
      );
    }
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
                  children: List.generate(2, (i) {
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
                      onNameChanged: () => setState(() {}),
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
                        _page == 1 ? 'Set Up My Wallet →' : 'Next →',
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
        return 220;
      case 1:
        return 360;
      default:
        return 400;
    }
  }
}

// ─────────────────────────────────────────────────────────────
class _Screen1 extends StatelessWidget {
  final TextEditingController nameCtrl;
  final VoidCallback onNameChanged;

  const _Screen1({required this.nameCtrl, required this.onNameChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
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
              hintText: 'Your Name',
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
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Screen 2: Quick Setup Guide (Step-by-step to get started)
// ─────────────────────────────────────────────────────────────
class _Screen3 extends StatelessWidget {
  const _Screen3();

  @override
  Widget build(BuildContext context) {
    const steps = [
      _SetupStepItem(
        stepNumber: '1',
        title: 'Add Your First Wallet',
        desc: 'Pick Cash, GCash, Maya, or Bank and input your current funds.',
        icon: Icons.account_balance_wallet_rounded,
        iconColor: 0xFF10B981,
      ),
      _SetupStepItem(
        stepNumber: '2',
        title: 'Configure Safe to Spend',
        desc: 'Set your Monthly payday and daily budget to prevent overspending.',
        icon: Icons.shield_outlined,
        iconColor: 0xFF6366F1,
      ),
      _SetupStepItem(
        stepNumber: '3',
        title: 'Log Daily & Stay on Track',
        desc: 'Tap + Income or ↑ Expense whenever money moves to see live limits.',
        icon: Icons.swap_vert_circle_rounded,
        iconColor: 0xFFF59E0B,
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Quick Setup Guide',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: kTextCharcoal,
                ),
              ),
              const SizedBox(width: 6),
              const Text('🚀', style: TextStyle(fontSize: 20)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '3 simple steps to get Gabay working for you:',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: kMuted,
            ),
          ),
          const SizedBox(height: 18),
          ...steps.map((s) => _SetupStepTile(step: s)),
        ],
      ),
    );
  }
}

class _SetupStepItem {
  final String stepNumber;
  final String title;
  final String desc;
  final IconData icon;
  final int iconColor;

  const _SetupStepItem({
    required this.stepNumber,
    required this.title,
    required this.desc,
    required this.icon,
    required this.iconColor,
  });
}

class _SetupStepTile extends StatelessWidget {
  final _SetupStepItem step;
  const _SetupStepTile({required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Color(step.iconColor).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  step.icon,
                  color: Color(step.iconColor),
                  size: 22,
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      color: Color(step.iconColor),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      step.stepNumber,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: kTextCharcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.desc,
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
