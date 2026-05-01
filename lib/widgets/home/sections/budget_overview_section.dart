import 'package:flutter/material.dart';
import 'package:gabay/config/app_theme.dart';
import 'package:gabay/widgets/home/tactile_button.dart';

// Renders the budget overview card with totals and progress.
class BudgetOverviewSection extends StatelessWidget {
  final double budget, total, plannedTotal, left, progress;
  final VoidCallback onTap;

  const BudgetOverviewSection({
    super.key,
    required this.budget,
    required this.total,
    required this.plannedTotal,
    required this.left,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    bool overBudget = total > budget && budget > 0;

    return TactileButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [kPrimarySoft, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [kShadowSoft],
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: kPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Budget Overview',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: kTextCharcoal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                BudgetCol(
                  label: 'BUDGET',
                  value: '₱${budget.toStringAsFixed(2)}',
                ),
                BudgetCol(
                  label: 'TOTAL',
                  value: '₱${total.toStringAsFixed(2)}',
                  subValue: '₱${plannedTotal.toStringAsFixed(2)}',
                  valueColor: kPrimary,
                ),
                BudgetCol(
                  label: 'LEFT',
                  value: '₱${left.toStringAsFixed(2)}',
                  valueColor: overBudget ? Colors.red : kTextCharcoal,
                ),
              ],
            ),
            if (overBudget)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_rounded,
                      color: Colors.red,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'You\'ve exceeded your budget!',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            // Progress bar driven by checked items' total value vs budget
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 10,
                color: kMutedBg,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0.0,
                    end: progress.clamp(0.0, 1.0),
                  ),
                  duration: const Duration(seconds: 1),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: value,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: value >= 1.0
                                ? [
                                    const Color(0xFF4CAF50),
                                    const Color(0xFF388E3C),
                                  ]
                                : [kPrimary, kPrimaryLight],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Renders one labeled budget metric inside the overview card.
class BudgetCol extends StatelessWidget {
  final String label, value;
  final String? subValue;
  final Color? valueColor;
  const BudgetCol({
    super.key,
    required this.label,
    required this.value,
    this.subValue,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: kMuted,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: valueColor ?? kTextCharcoal,
          ),
        ),
        if (subValue != null) ...[
          const SizedBox(height: 2),
          Text(
            subValue!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kMuted,
            ),
          ),
        ],
      ],
    );
  }
}
