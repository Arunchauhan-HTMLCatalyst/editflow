import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class PaymentOverview extends StatelessWidget {
  final double paid;
  final double pending;
  final double overdue;
  final String Function(double) formatValue;

  const PaymentOverview({
    super.key,
    required this.paid,
    required this.pending,
    required this.overdue,
    required this.formatValue,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = paid + pending + overdue;
    final paidFraction = total > 0 ? paid / total : 0.0;
    final pendingFraction = total > 0 ? pending / total : 0.0;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment Overview', style: AppTextStyles.title3(isDark)),
            SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 10,
                width: double.infinity,
                child: Row(
                  children: [
                    Flexible(
                      flex: (paidFraction * 100).toInt().clamp(1, 100),
                      child: Container(color: AppColors.success),
                    ),
                    if (pending > 0)
                      Flexible(
                        flex: (pendingFraction * 100).toInt().clamp(1, 100),
                        child: Container(color: AppColors.warning),
                      ),
                    if (overdue > 0)
                      Flexible(
                        flex: ((1 - paidFraction - pendingFraction) * 100).toInt().clamp(1, 100),
                        child: Container(color: AppColors.error),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: AppSpacing.md),
            _LegendRow(
              color: AppColors.success,
              label: 'Paid',
              value: formatValue(paid),
              isDark: isDark,
            ),
            SizedBox(height: AppSpacing.xs),
            _LegendRow(
              color: AppColors.warning,
              label: 'Pending',
              value: formatValue(pending),
              isDark: isDark,
            ),
            if (overdue > 0) ...[
              SizedBox(height: AppSpacing.xs),
              _LegendRow(
                color: AppColors.error,
                label: 'Overdue',
                value: formatValue(overdue),
                isDark: isDark,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  final bool isDark;

  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(label, style: AppTextStyles.small(isDark)),
        ),
        Text(value, style: AppTextStyles.caption(isDark)),
      ],
    );
  }
}
