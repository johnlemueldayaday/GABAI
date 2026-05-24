import 'package:flutter/material.dart';

const Map<String, String> kAccountIconAssets = {
  'gcash': 'assets/images/gcash.png',
  'maya': 'assets/images/paymaya.png',
  'paymaya': 'assets/images/paymaya.png',
  'cash': 'assets/images/cash.png',
  'bdo': 'assets/images/bdo.png',
  'landbank': 'assets/images/landbank.png',
  'psbank': 'assets/images/psbank.png',
};

String? accountIconAssetFor(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.startsWith('assets/images/')) return value;
  return kAccountIconAssets[normalized];
}

String? accountIconAssetForAccount({
  required String name,
  required String icon,
}) {
  return accountIconAssetFor(icon) ?? accountIconAssetFor(name);
}

class AccountIconImage extends StatelessWidget {
  final String name;
  final String icon;
  final double size;
  final BoxFit fit;

  const AccountIconImage({
    super.key,
    required this.name,
    required this.icon,
    this.size = 24,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final assetPath = accountIconAssetForAccount(name: name, icon: icon);
    if (assetPath == null) {
      return Text(icon, style: TextStyle(fontSize: size));
    }

    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: fit,
    );
  }
}
