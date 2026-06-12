import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/project.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../settings/models/currency_config.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/providers/computed_providers.dart';

class ProjectCard extends StatelessWidget {
  final Project project;
  final VoidCallback onTap;
  final CurrencyConfig? currency;

  const ProjectCard({super.key, required this.project, required this.onTap, this.currency});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = currency ?? CurrencyConfig.usd;
    final overdue = isProjectOverdue(project);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.cardPadding, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      project.name,
                      style: AppTextStyles.label(isDark).copyWith(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text(
                    c.format(project.price),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textPrimary : const Color(0xFF18181B),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Pending ${c.format(project.remainingAmount)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Spacer(),
                  if (project.deadline != null)
                    Text(
                      DateFormat('MMM d').format(project.deadline!),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: overdue ? AppColors.error : AppColors.textMuted,
                      ),
                    ),
                  SizedBox(width: AppSpacing.sm),
                  StatusBadge(status: project.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
