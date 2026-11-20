String formatQty(double q) {
  if ((q - 0.125).abs() < 0.001) return '⅛';
  if ((q - 0.25).abs() < 0.001) return '¼';
  if ((q - 0.333).abs() < 0.001) return '⅓';
  if ((q - 0.5).abs() < 0.001) return '½';
  if ((q - 0.666).abs() < 0.001) return '⅔';
  if ((q - 0.75).abs() < 0.001) return '¾';
  if ((q - 1.25).abs() < 0.001) return '1¼';
  if ((q - 1.5).abs() < 0.001) return '1½';
  if ((q - 1.75).abs() < 0.001) return '1¾';
  if (q == q.truncateToDouble()) return q.toInt().toString();
  return q
      .toStringAsFixed(3)
      .replaceAll(RegExp(r'0*$'), '')
      .replaceAll(RegExp(r'\.$'), '');
}

const _kgQtySteps = [
  0.125,
  0.25,
  0.5,
  0.75,
  1.0,
  1.25,
  1.5,
  1.75,
  2.0,
  2.5,
  3.0,
  4.0,
  5.0,
];

bool isValidQty(double qty, String unit) {
  if (!qty.isFinite) return false;
  if (unit == 'kg') {
    return _kgQtySteps.contains(qty) ||
        (qty >= 6 && qty == qty.roundToDouble());
  }
  return qty >= 1 && qty <= 999 && qty == qty.roundToDouble();
}

double stepQty(double current, int dir, String unit) {
  if (unit == 'kg') {
    if (dir > 0) {
      for (double s in _kgQtySteps) {
        if (s > current + 0.001) return s;
      }
      return current + 1.0;
    } else {
      for (int i = _kgQtySteps.length - 1; i >= 0; i--) {
        if (_kgQtySteps[i] < current - 0.001) return _kgQtySteps[i];
      }
      return current > 1.0 ? current - 1.0 : 0.125;
    }
  } else {
    return (current + dir).clamp(1.0, 999.0);
  }
}

double getItemTotal(double price, double qty, String unit) {
  if (unit == 'g' || unit == 'mL') {
    return (price / 1000) * qty;
  }
  return price * qty;
}
