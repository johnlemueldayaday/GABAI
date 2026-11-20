import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gabay/config/app_theme.dart';

// Renders a press-responsive wrapper for tappable child widgets.
class TactileButton extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  final bool hapticFeedback;
  const TactileButton({
    super.key,
    required this.onTap,
    required this.child,
    this.hapticFeedback = false,
  });

  @override
  State<TactileButton> createState() => TactileButtonState();
}

// Manages the pressed animation state for TactileButton.
class TactileButtonState extends State<TactileButton> {
  bool _isDown = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isDown = true),
      onTapUp: (_) {
        setState(() => _isDown = false);
        if (widget.hapticFeedback) {
          unawaited(HapticFeedback.selectionClick());
        }
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isDown = false),
      child: AnimatedScale(
        scale: _isDown ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class QuantityStepButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  const QuantityStepButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: TactileButton(
        onTap: onTap,
        hapticFeedback: true,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [kCardBg, kBackground],
                ),
                border: Border.all(color: kBorder),
                boxShadow: [
                  BoxShadow(
                    color: kTextCharcoal.withValues(alpha: 0.12),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                    spreadRadius: -1,
                  ),
                  BoxShadow(
                    color: kCardBg.withValues(alpha: 0.8),
                    offset: const Offset(0, -1),
                    blurRadius: 1,
                  ),
                ],
              ),
              child: Icon(icon, size: 18, color: kTextCharcoal),
            ),
          ),
        ),
      ),
    );
  }
}
