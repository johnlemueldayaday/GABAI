import 'package:flutter/material.dart';

// Provides the spring-like curve used by the add-item sheet animation.
class SpringCurve extends Curve {
  final double damping;
  final double stiffness;

  const SpringCurve({this.damping = 30, this.stiffness = 300});

  @override
  double transformInternal(double t) {
    // Attempt to approximate a critically-damped spring with the given params
    final omega = stiffness / damping; // ~10
    final decay = -omega * t;
    return 1.0 -
        (1.0 + omega * t * 0.5) * (2.718281828 * decay).clamp(0.0, 1.0);
  }
}

// Renders a child with a delayed pop-in scale animation.
class StaggeredPop extends StatefulWidget {
  final Widget child;
  final int delay;
  const StaggeredPop({super.key, required this.child, required this.delay});

  @override
  State<StaggeredPop> createState() => StaggeredPopState();
}

// Manages the delayed pop-in animation for StaggeredPop.
class StaggeredPopState extends State<StaggeredPop>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}
