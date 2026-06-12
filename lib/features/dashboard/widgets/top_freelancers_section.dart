import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/computed_providers.dart';

class TopFreelancersSection extends StatelessWidget {
  final List<TopFreelancerEntry> freelancers;

  const TopFreelancersSection({
    super.key,
    required this.freelancers,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
            width: 0.8,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Freelancers', style: AppTextStyles.title3(isDark)),
                  Text(
                    'by deadlines',
                    style: AppTextStyles.small(isDark).copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (freelancers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: Text('No freelancers assigned', style: AppTextStyles.small(isDark)),
                  ),
                )
              else
                Column(
                  children: freelancers.asMap().entries.map((entry) {
                    final index = entry.key;
                    final data = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == freelancers.length - 1 ? 0 : 10.0,
                      ),
                      child: _FreelancerRankItem(
                        rank: index + 1,
                        data: data,
                        isDark: isDark,
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FreelancerRankItem extends StatelessWidget {
  final int rank;
  final TopFreelancerEntry data;
  final bool isDark;

  const _FreelancerRankItem({
    required this.rank,
    required this.data,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final deadlineStr = data.nextDeadline != null
        ? DateFormat('MMM d').format(data.nextDeadline!)
        : 'None';

    return GestureDetector(
      onTap: () => context.push('/freelancers/${data.id}'),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
        child: Row(
          children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
              ),
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.primaryNeon.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
                width: 0.8,
              ),
            ),
            child: Center(
              child: Text(
                data.name.isNotEmpty ? data.name[0].toUpperCase() : 'F',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.name,
                  style: AppTextStyles.label(isDark).copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${data.activeProjectsCount} active projects',
                  style: AppTextStyles.small(isDark).copyWith(
                    fontSize: 11,
                    color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Next Deadline',
                style: AppTextStyles.small(isDark).copyWith(
                  fontSize: 10,
                  color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                deadlineStr,
                style: AppTextStyles.label(isDark).copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: data.nextDeadline != null && data.nextDeadline!.isBefore(DateTime.now())
                      ? AppColors.error
                      : AppColors.primaryNeon,
                ),
              ),
            ],
          ),
        ],
      ),
    ));
  }
}
