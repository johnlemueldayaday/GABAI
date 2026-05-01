import 'package:flutter/material.dart';

// Renders the drag handle shown at the top of modal sheets.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 4),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFDDDDDD),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
