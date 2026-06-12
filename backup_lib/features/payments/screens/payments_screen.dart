import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../projects/providers/project_provider.dart';
import '../../projects/models/project.dart';
import '../../projects/models/project_status.dart';
import '../../../shared/providers/computed_providers.dart';
import '../../../shared/widgets/loading_widget.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../settings/providers/settings_provider.dart';
import '../../settings/models/currency_config.dart';

class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final projectsAsync = ref.watch(projectProvider);
    final currency = ref.watch(currencyProvider);
    final overview = ref.watch(paymentOverviewProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Payments',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: projectsAsync.when(
        loading: () => LoadingWidget(message: 'Loading payments...'),
        error: (e, _) => Center(
          child: Text('Error: ${e.toString()}'),
        ),
        data: (_) {
          return SingleChildScrollView(
              padding: EdgeInsets.all(AppLayout.pagePadding(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    'Overview',
                    style: AppTextStyles.title2(isDark),
                  ),
                  SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          label: 'Total',
                          value: currency.format(overview.totalAmount),
                          color: AppColors.primary,
                          isDark: isDark,
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _SummaryCard(
                          label: 'Advance',
                          value: currency.format(overview.receivedAmount),
                          color: AppColors.success,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          label: 'Remaining',
                          value: currency.format(overview.remaining),
                          color: AppColors.warning,
                          isDark: isDark,
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _SummaryCard(
                          label: 'Paid Projects',
                          value: '${overview.paidProjects.length}',
                          color: AppColors.success,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.lg),
                  if (overview.overdueProjects.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 16, color: AppColors.error),
                        SizedBox(width: AppSpacing.xs),
                        Text(
                          'Overdue Payments',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.sm),
                    ...overview.overdueProjects.map((p) => RepaintBoundary(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _OverdueCard(project: p, isDark: isDark, currency: currency),
                          ),
                        )),
                    SizedBox(height: AppSpacing.md),
                  ],
                  Text(
                    'All Projects',
                    style: AppTextStyles.title3(isDark),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  if ((projectsAsync.valueOrNull ?? []).isEmpty)
                    EmptyStateWidget(
                      icon: Icons.attach_money,
                      title: 'No payments yet',
                      subtitle: 'Create a project to start tracking payments',
                    )
                  else
                    ...(projectsAsync.valueOrNull ?? []).map((p) => RepaintBoundary(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _PaymentProjectCard(
                                project: p, isDark: isDark, currency: currency),
                          ),
                        )),
                  SizedBox(height: AppSpacing.xxl),
                ],
              ),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverdueCard extends StatelessWidget {
  final Project project;
  final bool isDark;
  final CurrencyConfig currency;

  const _OverdueCard({required this.project, required this.isDark, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.alarm, size: 18, color: AppColors.error),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(project.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                )),
                SizedBox(height: 2),
                Text(
                  '${currency.format(project.remainingAmount)} overdue',
                  style: TextStyle(fontSize: 12, color: AppColors.error),
                ),
              ],
            ),
          ),
          Text(
            DateFormat('MMM d').format(project.deadline!),
            style: TextStyle(fontSize: 12, color: AppColors.error),
          ),
        ],
      ),
    );
  }
}

class _PaymentProjectCard extends StatelessWidget {
  final Project project;
  final bool isDark;
  final CurrencyConfig currency;

  const _PaymentProjectCard({required this.project, required this.isDark, required this.currency});

  @override
  Widget build(BuildContext context) {
    final progress = project.price > 0
        ? (project.receivedAmount / project.price * 100).toStringAsFixed(0)
        : '0';

    return Container(
      padding: EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(project.name, style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                   color: project.status == ProjectStatus.paid
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  currency.format(project.remainingAmount),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: project.status == ProjectStatus.paid
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${currency.format(project.receivedAmount)} / ${currency.format(project.price)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Text('$progress%', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              )),
            ],
          ),
          SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Container(
              height: 4,
              width: double.infinity,
              color: isDark ? const Color(0xFF2E2E3E) : const Color(0xFFE2E4E9),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (project.receivedAmount / project.price).clamp(0, 1),
                child: Container(
                  color: project.status == ProjectStatus.paid
                      ? AppColors.success
                      : AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
