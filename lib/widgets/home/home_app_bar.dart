import 'package:flutter/material.dart';
import 'package:gabay/config/app_theme.dart';

// Renders the home screen app bar with drawer access.
class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HomeAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: Builder(
        builder: (context) => IconButton(
          icon: Icon(Icons.menu_rounded, color: kTextCharcoal),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: const Text('Cart'),
    );
  }
}
