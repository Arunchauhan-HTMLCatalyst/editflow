import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/project_provider.dart';
import '../widgets/project_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/animated_list_item.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/project_status.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  String _searchQuery = '';

  Widget _buildSummaryChip({
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final projectsAsync = ref.watch(projectProvider);
    final currency = ref.watch(currencyProvider);
    final isClient = ref.watch(settingsProvider).isClientMode;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20.0,
        title: Text(
          'Projects',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
          ),
        ),
        actions: [
          if (!isClient) ...[
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surface : CupertinoColors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                    width: 0.8,
                  ),
                ),
                child: const Icon(
                  CupertinoIcons.add,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              onPressed: () => context.push('/projects/add'),
            ),
            const SizedBox(width: 16),
          ],
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 16.0),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search projects...',
                prefixIcon: const Icon(CupertinoIcons.search, size: 18),
                contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
              ),
              style: TextStyle(
                color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: projectsAsync.when(
              loading: () => LoadingWidget(message: 'Loading projects...'),
              error: (e, _) => ErrorStateWidget(
                message: e.toString(),
                onRetry: () => ref.read(projectProvider.notifier).refresh(),
              ),
              data: (projects) {
                final filtered = projects
                    .where((p) =>
                        p.name.toLowerCase().contains(_searchQuery) ||
                        (p.clientName?.toLowerCase().contains(_searchQuery) ?? false))
                    .toList();

                final activeCount = projects.where((p) =>
                  p.status == ProjectStatus.yetToStart ||
                  p.status == ProjectStatus.inProgress ||
                  p.status == ProjectStatus.revisionPending
                ).length;

                final completedCount = projects.where((p) =>
                  p.status == ProjectStatus.completed ||
                  p.status == ProjectStatus.paid
                ).length;

                final overdueCount = projects.where((p) {
                  if (p.deadline == null) return false;
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final deadlineDate = DateTime(p.deadline!.year, p.deadline!.month, p.deadline!.day);
                  return deadlineDate.isBefore(today);
                }).length;

                if (projects.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.folder,
                    title: 'No projects yet',
                    subtitle: 'Create your first project',
                    actionLabel: 'Add Project',
                    onAction: () => context.push('/projects/add'),
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Row(
                        children: [
                          _buildSummaryChip(
                            label: '$activeCount Active',
                            color: AppColors.primary,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildSummaryChip(
                            label: '$overdueCount Overdue',
                            color: AppColors.error,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildSummaryChip(
                            label: '$completedCount Completed',
                            color: const Color(0xFF22C55E),
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filtered.isEmpty
                          ? EmptyStateWidget(
                              icon: Icons.folder,
                              title: 'No projects found',
                              subtitle: 'Try a different search',
                              actionLabel: 'Add Project',
                              onAction: () => context.push('/projects/add'),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.all(AppSpacing.pageHorizontal),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final project = filtered[index];
                                return AnimatedListItem(
                                  index: index,
                                  child: Padding(
                                    padding: EdgeInsets.only(bottom: AppSpacing.sm),
                                    child: ProjectCard(
                                      project: project,
                                      currency: currency,
                                      onTap: () => context.push('/projects/${project.id}'),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
