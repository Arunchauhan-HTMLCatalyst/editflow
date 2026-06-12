import 'package:flutter/material.dart';
import '../../projects/models/project_status.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/constants/status_colors.dart';

class PipelineCard extends StatelessWidget {
  final Map<ProjectStatus, int> pipelineData;

  const PipelineCard({super.key, required this.pipelineData});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = pipelineData.values.fold(0, (a, b) => a + b);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Project Pipeline', style: AppTextStyles.title3(isDark)),
                Text('$total projects', style: AppTextStyles.small(isDark)),
              ],
            ),
            SizedBox(height: AppSpacing.lg),
            ...ProjectStatus.values.where((s) => (pipelineData[s] ?? 0) > 0).map((status) {
              final count = pipelineData[status] ?? 0;
              final fraction = total > 0 ? count / total : 0.0;
              return _PipelineItem(
                label: status.displayName,
                count: count,
                fraction: fraction,
                color: _statusColor(status),
              );
            }),
            if (ProjectStatus.values.every((s) => (pipelineData[s] ?? 0) == 0))
              Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(
                  child: Text('No projects yet', style: AppTextStyles.small(isDark)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(ProjectStatus status) => statusColor(status);
}

class _PipelineItem extends StatelessWidget {
  final String label;
  final int count;
  final double fraction;
  final Color color;

  const _PipelineItem({
    required this.label,
    required this.count,
    required this.fraction,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text(label, style: AppTextStyles.caption(isDark)),
                ],
              ),
              Text('$count', style: AppTextStyles.caption(isDark)),
            ],
          ),
          SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Container(
              height: 4,
              width: double.infinity,
              color: AppColors.border.withValues(alpha: 0.5),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fraction,
                child: Container(color: color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
