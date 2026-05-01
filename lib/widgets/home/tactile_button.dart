import 'package:flutter/material.dart';

// Renders a press-responsive wrapper for tappable child widgets.
class TactileButton extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  const TactileButton({super.key, required this.onTap, required this.child});

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
