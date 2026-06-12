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
import '../../settings/providers/settings_provider.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final projectsAsync = ref.watch(projectProvider);
    final currency = ref.watch(currencyProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Projects',
          style: TextStyle(
            fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textPrimary : const Color(0xFF18181B),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: AppColors.primary),
            onPressed: () => context.push('/projects/add'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              AppSpacing.sm,
              AppSpacing.pageHorizontal,
              AppSpacing.sm,
            ),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search projects...',
                hintStyle: TextStyle(
                  color: isDark ? AppColors.textMuted : const Color(0xFF71717A),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: isDark ? AppColors.textMuted : const Color(0xFF71717A),
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF252535) : const Color(0xFFF1F3F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.all(AppSpacing.sm),
              ),
              style: TextStyle(
            color: isDark ? AppColors.textPrimary : const Color(0xFF18181B),
                fontSize: 15,
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

                if (filtered.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.folder,
                    title: _searchQuery.isNotEmpty
                        ? 'No projects found'
                        : 'No projects yet',
                    subtitle: _searchQuery.isNotEmpty
                        ? 'Try a different search'
                        : 'Create your first project',
                    actionLabel: 'Add Project',
                    onAction: () => context.push('/projects/add'),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(AppSpacing.pageHorizontal),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final project = filtered[index];
                    return RepaintBoundary(
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
