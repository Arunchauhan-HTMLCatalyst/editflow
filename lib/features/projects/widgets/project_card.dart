import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/project.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../settings/models/currency_config.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/constants/status_colors.dart';

class ProjectCard extends StatefulWidget {
  final Project project;
  final VoidCallback onTap;
  final CurrencyConfig? currency;
  final bool isSelectMode;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectedChanged;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;

  const ProjectCard({
    super.key,
    required this.project,
    required this.onTap,
    this.currency,
    this.isSelectMode = false,
    this.isSelected = false,
    this.onSelectedChanged,
    this.onLongPress,
    this.onSecondaryTap,
  });

  @override
  State<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<ProjectCard> {

  Widget _buildDeadlineWidget(BuildContext context, DateTime deadline, bool isDark) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadlineDate = DateTime(deadline.year, deadline.month, deadline.day);
    final difference = deadlineDate.difference(today).inDays;

    if (difference < 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: AppColors.error.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.report_problem, size: 10, color: AppColors.error),
            const SizedBox(width: 4),
            Text(
              'Overdue',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      );
    } else if (difference <= 3) {
      const amberColor = Color(0xFFD97706);
      final label = difference == 0
          ? 'Due today'
          : difference == 1
              ? 'Due tomorrow'
              : 'Due in $difference days';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        decoration: BoxDecoration(
          color: amberColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: amberColor.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: amberColor,
          ),
        ),
      );
    } else {
      return Text(
        DateFormat('MMM d').format(deadline),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = widget.currency ?? CurrencyConfig.usd;
    final statusCol = statusColor(widget.project.status);

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.card : Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: widget.isSelected
                ? AppColors.primary
                : (isDark ? AppColors.border : const Color(0xFFE2E8F0)),
            width: widget.isSelected ? 1.5 : 0.9,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            onSecondaryTap: widget.onSecondaryTap,
            borderRadius: BorderRadius.circular(16.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.0),
              child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: statusCol,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),
                  if (widget.isSelectMode)
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: Center(
                        child: CupertinoCheckbox(
                          value: widget.isSelected,
                          activeColor: AppColors.primary,
                          onChanged: widget.onSelectedChanged,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (widget.project.isFolder) ...[
                                          const Icon(Icons.folder_rounded, size: 16, color: AppColors.primary),
                                          const SizedBox(width: 6),
                                        ],
                                        Expanded(
                                          child: Text(
                                            widget.project.name,
                                            style: AppTextStyles.label(isDark).copyWith(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (widget.project.clientName != null &&
                                        widget.project.clientName!.trim().isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        widget.project.clientName!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (widget.project.isSubProject)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Included',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white70 : AppColors.textSecondary,
                                    ),
                                  ),
                                )
                              else
                                Text(
                                  widget.project.isFolder 
                                      ? 'Monthly ${c.format(widget.project.price)}'
                                      : c.format(widget.project.price),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              if (widget.project.isFolder)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: const Text(
                                    'Monthly Retainer',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF8B5CF6),
                                    ),
                                  ),
                                )
                              else if (!widget.project.isSubProject)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(alpha: 0.12),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    'Due ${c.format(widget.project.remainingAmount)}',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              const Spacer(),
                              if (widget.project.deadline != null)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: _buildDeadlineWidget(context, widget.project.deadline!, isDark),
                                ),
                              StatusBadge(
                                status: widget.project.status,
                                isFolder: widget.project.isFolder,
                              ),
                            ],
                          ),
                          if (widget.project.price > 0 && !widget.project.isFolder && !widget.project.isSubProject) ...[
                            const SizedBox(height: 12),
                            Container(
                              height: 3,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(1.5),
                              ),
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: (widget.project.receivedAmount / widget.project.price).clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.primary,
                                        AppColors.primary.withValues(alpha: 0.7),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(1.5),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}

