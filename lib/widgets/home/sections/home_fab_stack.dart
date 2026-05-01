import 'package:flutter/material.dart';
import 'package:gabay/pages/ramsey.dart';
import 'package:gabay/widgets/home/sections/bouncing_add_fab.dart';

// Renders the stacked floating action buttons shown on the home screen.
class HomeFabStack extends StatelessWidget {
  final VoidCallback onAddPressed;

  const HomeFabStack({super.key, required this.onAddPressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const RamseyFab(),
        const SizedBox(height: 12),
        BouncingAddFab(onPressed: onAddPressed),
      ],
    );
  }
}
