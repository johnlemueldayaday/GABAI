import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_theme.dart';

void showPwaInstallGuide(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _PwaInstallSheet(),
  );
}

class _PwaInstallSheet extends StatelessWidget {
  const _PwaInstallSheet();

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: kBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header with App Icon
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 52,
                    height: 52,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: kPrimary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Install Gabay App',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: kTextCharcoal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'No browser bars • Never expires',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: kPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: kMuted),
                ),
              ],
            ),

            const SizedBox(height: 20),
            Text(
              isIOS
                  ? 'Follow these 3 quick steps in Safari to add Gabay to your iPhone Home Screen:'
                  : 'Install Gabay as a Progressive Web App on your home screen or desktop:',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: kMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),

            if (isIOS) ...[
              _buildStepTile(
                number: '1',
                icon: CupertinoIcons.share,
                title: 'Tap the Share Button',
                subtitle: 'Look for the share icon (square with arrow) at the bottom of Safari.',
              ),
              const SizedBox(height: 12),
              _buildStepTile(
                number: '2',
                icon: Icons.add_box_outlined,
                title: 'Select "Add to Home Screen"',
                subtitle: 'Scroll down the share menu options and tap "Add to Home Screen".',
              ),
              const SizedBox(height: 12),
              _buildStepTile(
                number: '3',
                icon: Icons.check_circle_outline,
                title: 'Tap "Add" in the top right',
                subtitle: 'Gabay will be saved with its custom icon on your iPhone home screen!',
              ),
            ] else ...[
              _buildStepTile(
                number: '1',
                icon: Icons.more_vert,
                title: 'Open Browser Menu',
                subtitle: 'Tap the three dots menu ⋮ in Chrome or your browser.',
              ),
              const SizedBox(height: 12),
              _buildStepTile(
                number: '2',
                icon: Icons.install_mobile,
                title: 'Select "Install app" or "Add to Home Screen"',
                subtitle: 'Tap to install Gabay directly to your home screen or desktop.',
              ),
            ],

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Got it!',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepTile({
    required String number,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: GoogleFonts.plusJakartaSans(
                  color: kPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: kTextCharcoal,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(icon, size: 16, color: kPrimary),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: kMuted,
                    height: 1.3,
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
