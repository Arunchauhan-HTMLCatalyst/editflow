import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/computed_providers.dart';
import '../../../shared/widgets/animated_list_item.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../projects/widgets/project_card.dart';
import '../../settings/providers/settings_provider.dart';

class FreelancerDetailScreen extends ConsumerWidget {
  final String freelancerId;

  const FreelancerDetailScreen({
    super.key,
    required this.freelancerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final padding = AppLayout.pagePadding(context);
    final currency = ref.watch(currencyProvider);
    final projects = ref.watch(freelancerProjectsProvider(freelancerId));

    // Get freelancer details from first project
    String name = 'Freelancer';
    for (final p in projects) {
      if (p.freelancerName != null && p.freelancerName!.isNotEmpty) {
        name = p.freelancerName!;
        break;
      }
    }

    final initials = name.isNotEmpty
        ? name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : '?';

    // Metrics for this freelancer
    final totalPaid = projects.fold<double>(0.0, (s, p) => s + p.receivedAmount);
    final totalRemaining = projects.fold<double>(0.0, (s, p) => s + p.remainingAmount);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            child: Container(
              padding: const EdgeInsets.all(6.0),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface : CupertinoColors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                  width: 0.8,
                ),
              ),
              child: Icon(
                CupertinoIcons.back,
                size: 18,
                color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
              ),
            ),
            onPressed: () => context.pop(),
          ),
        ),
        title: Text(
          'Freelancer Profile',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(padding),
          children: [
            // Avatar and Name Header Card
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.primaryGradient,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: AppTextStyles.title1(isDark).copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Active Collaborator',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.primaryNeon : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Summary metrics cards row
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Projects',
                    value: '${projects.length}',
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    label: 'Total Paid',
                    value: currency.format(totalPaid),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    label: 'Due',
                    value: currency.format(totalRemaining),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Projects List Title
            Text(
              'PROJECTS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),

            if (projects.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40.0),
                child: EmptyStateWidget(
                  icon: Icons.assignment_outlined,
                  title: 'No Projects Found',
                  subtitle: 'There are no projects assigned under this freelancer.',
                ),
              )
            else
              ...List.generate(projects.length, (index) {
                final project = projects[index];
                return AnimatedListItem(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: ProjectCard(
                      project: project,
                      onTap: () => context.push('/projects/${project.id}'),
                      currency: currency,
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 10.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
        boxShadow: isDark
            ? []
            : [
                const BoxShadow(
                  color: Color(0x050F172A),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                )
              ],
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
