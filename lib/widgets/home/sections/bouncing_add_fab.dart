import 'package:flutter/material.dart';
import 'package:gabay/config/app_theme.dart';

// Renders the animated circular add-item floating action button.
class BouncingAddFab extends StatefulWidget {
  final VoidCallback onPressed;
  const BouncingAddFab({super.key, required this.onPressed});

  @override
  State<BouncingAddFab> createState() => BouncingAddFabState();
}

// Manages the pressed animation state for BouncingAddFab.
class BouncingAddFabState extends State<BouncingAddFab> {
  bool _isDown = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isDown = true),
      onTapUp: (_) {
        setState(() => _isDown = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isDown = false),
      child: AnimatedScale(
        scale: _isDown ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutQuad,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [kPrimary, kPrimaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: kPrimary.withValues(alpha: 0.3),
                offset: const Offset(0, 8),
                blurRadius: 16,
              ),
            ],
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
