import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/models/activity.dart';

class RecentActivityWidget extends StatelessWidget {
  final List<Activity> activities;

  const RecentActivityWidget({super.key, required this.activities});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent Activity', style: AppTextStyles.title3(isDark)),
            SizedBox(height: AppSpacing.lg),
            if (activities.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(
                  child: Text('No recent activity', style: AppTextStyles.small(isDark)),
                ),
              )
            else
              ...activities.map((a) => _ActivityItem(activity: a)),
          ],
        ),
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final Activity activity;

  const _ActivityItem({required this.activity});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFormat = DateFormat('MMM d, h:mm a');

    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.md),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Timeline line
            Column(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _iconColor(activity.type).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 1,
                    color: AppColors.border.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.description,
                    style: AppTextStyles.caption(isDark),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    dateFormat.format(activity.createdAt.toLocal()),
                    style: AppTextStyles.small(isDark),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _iconColor(String type) {
    switch (type) {
      case 'project_created':
      case 'client_created':
        return AppColors.success;
      case 'project_updated':
        return AppColors.primary;
      case 'payment_received':
        return AppColors.success;
      default:
        return AppColors.textMuted;
    }
  }
}
