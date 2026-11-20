import 'package:flutter/material.dart';
import 'package:gabay/config/app_theme.dart';
import 'package:gabay/widgets/home/home_helpers.dart';
import 'package:gabay/widgets/home/sections/sheet_handle.dart';
import 'package:gabay/widgets/home/tactile_button.dart';

// Renders the price entry bottom sheet with a custom numeric keypad.
class NumericKeypadSheet extends StatefulWidget {
  final double initialValue;
  final String itemName;
  final String? quantityUnit;
  const NumericKeypadSheet({
    super.key,
    required this.initialValue,
    required this.itemName,
    this.quantityUnit,
  });

  @override
  State<NumericKeypadSheet> createState() => NumericKeypadSheetState();
}

// Manages the numeric keypad display and confirmation behavior.
class NumericKeypadSheetState extends State<NumericKeypadSheet> {
  String _display = '';
  bool _replaceInitialQty = false;

  @override
  void initState() {
    super.initState();
    _display = widget.quantityUnit == null
        ? ''
        : _formatInitialValue(widget.initialValue);
    _replaceInitialQty = widget.quantityUnit != null;
  }

  double get _currentValue => double.tryParse(_display) ?? 0.0;
  bool get _isQuantity => widget.quantityUnit != null;

  bool get _canConfirm {
    final unit = widget.quantityUnit;
    return unit == null ||
        (_replaceInitialQty && _display.isNotEmpty) ||
        isValidQty(_currentValue, unit);
  }

  static String _formatInitialValue(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  void _onDigit(String digit) {
    setState(() {
      var display = _replaceInitialQty ? '' : _display;
      _replaceInitialQty = false;

      // If empty and typing '.', start with '0.'
      if (display.isEmpty && digit == '.') {
        _display = '0.';
        return;
      }
      // If display is '0' and typing a non-dot digit, replace it
      if (display == '0' && digit != '.') {
        _display = digit;
        return;
      }
      // Only allow one decimal point
      if (digit == '.' && display.contains('.')) return;
      final maxDecimalPlaces = _isQuantity ? 3 : 2;
      if (display.contains('.')) {
        final decimals = display.split('.').last;
        if (decimals.length >= maxDecimalPlaces) return;
      }
      // Limit total length
      if (display.length >= 10) return;
      display += digit;
      _display = display;
    });
  }

  void _onBackspace() {
    setState(() {
      _replaceInitialQty = false;
      if (_display.isNotEmpty) {
        _display = _display.substring(0, _display.length - 1);
      }
    });
  }

  void _onClear() {
    setState(() {
      _replaceInitialQty = false;
      _display = '';
    });
  }

  void _onConfirm() {
    if (!_canConfirm) return;
    Navigator.pop(context, _currentValue);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            // ─── Header ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isQuantity ? 'Edit Quantity' : 'Edit Price',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: kTextCharcoal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.itemName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: kMuted,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: kMutedBg,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(Icons.close, size: 16, color: kMuted),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ─── Value Display ───────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: BoxDecoration(
                color: kBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  if (!_isQuantity) ...[
                    Text(
                      '₱',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: kPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    _display.isEmpty ? (_isQuantity ? '0' : '0.00') : _display,
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: _display.isEmpty
                          ? kTextCharcoal.withValues(alpha: 0.3)
                          : kTextCharcoal,
                      letterSpacing: -1,
                    ),
                  ),
                  if (widget.quantityUnit case final unit?) ...[
                    const SizedBox(width: 8),
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: kMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_isQuantity && !_canConfirm)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  widget.quantityUnit == 'kg'
                      ? 'Use the available kg increments, or whole kg above 5.'
                      : 'Enter a whole quantity from 1 to 999.',
                  style: TextStyle(fontSize: 12, color: kMuted),
                ),
              ),
            const SizedBox(height: 20),
            // ─── Keypad Grid ────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildKeyRow(['1', '2', '3']),
                  const SizedBox(height: 10),
                  _buildKeyRow(['4', '5', '6']),
                  const SizedBox(height: 10),
                  _buildKeyRow(['7', '8', '9']),
                  const SizedBox(height: 10),
                  _buildKeyRow(['.', '0', '⌫']),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ─── Action Buttons ──────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // Clear button
                  Expanded(
                    flex: 1,
                    child: TactileButton(
                      onTap: _onClear,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: kMutedBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            'Clear',
                            style: TextStyle(
                              color: kMuted,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Confirm button
                  Expanded(
                    flex: 2,
                    child: IgnorePointer(
                      ignoring: !_canConfirm,
                      child: Opacity(
                        opacity: _canConfirm ? 1 : 0.5,
                        child: Semantics(
                          button: true,
                          enabled: _canConfirm,
                          child: TactileButton(
                            onTap: _onConfirm,
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [kPrimary, kPrimaryLight],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: kPrimary.withValues(alpha: 0.25),
                                    offset: const Offset(0, 6),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _isQuantity
                                          ? 'Confirm  $_display ${widget.quantityUnit}'
                                          : 'Confirm  ₱${_currentValue.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyRow(List<String> keys) {
    return Row(
      children: keys.map((key) {
        final isBackspace = key == '⌫';
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: keys.indexOf(key) == 0 ? 0 : 5,
              right: keys.indexOf(key) == keys.length - 1 ? 0 : 5,
            ),
            child: KeypadButton(
              label: key,
              isBackspace: isBackspace,
              onTap: isBackspace ? _onBackspace : () => _onDigit(key),
              onLongPress: isBackspace ? _onClear : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// Renders one press-responsive key in the numeric keypad.
class KeypadButton extends StatefulWidget {
  final String label;
  final bool isBackspace;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const KeypadButton({
    super.key,
    required this.label,
    this.isBackspace = false,
    required this.onTap,
    this.onLongPress,
  });

  @override
  State<KeypadButton> createState() => KeypadButtonState();
}

// Manages the pressed animation state for KeypadButton.
class KeypadButtonState extends State<KeypadButton> {
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
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        height: 56,
        decoration: BoxDecoration(
          color: _isDown ? kPrimary.withValues(alpha: 0.1) : kBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isDown ? kPrimary.withValues(alpha: 0.3) : kBorder,
          ),
        ),
        child: Center(
          child: widget.isBackspace
              ? Icon(Icons.backspace_outlined, size: 22, color: kTextCharcoal)
              : Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: kTextCharcoal,
                  ),
                ),
        ),
      ),
    );
  }
}
