import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/project_provider.dart';
import '../widgets/project_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_layout.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/animated_list_item.dart';
import '../../../shared/providers/computed_providers.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/project_status.dart';
import '../../../shared/utils/premium_helper.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

enum ProjectListFilter { all, active, overdue, completed }

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  String _searchQuery = '';
  ProjectListFilter _selectedFilter = ProjectListFilter.all;
  bool _isSelectMode = false;
  final Set<String> _selectedProjectIds = {};

  Widget _buildSummaryChip({
    required String label,
    required Color color,
    required bool isDark,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.15),
            width: 0.8,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  Future<void> _handleBatchDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Projects'),
        content: Text('Are you sure you want to delete these ${_selectedProjectIds.length} projects? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final ids = _selectedProjectIds.toList();
      setState(() {
        _isSelectMode = false;
        _selectedProjectIds.clear();
      });
      final notifier = ref.read(projectProvider.notifier);
      for (final id in ids) {
        await notifier.deleteProject(id);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Projects deleted successfully')),
      );
    }
  }

  Future<void> _handleBatchStatusUpdate() async {
    final status = await showDialog<ProjectStatus>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batch Update Status'),
        content: const Text('Select the status to apply to all selected projects:'),
        actions: ProjectStatus.values.map((s) {
          return TextButton(
            onPressed: () => Navigator.of(ctx).pop(s),
            child: Text(s.displayName),
          );
        }).toList(),
      ),
    );

    if (status != null && mounted) {
      final ids = _selectedProjectIds.toList();
      setState(() {
        _isSelectMode = false;
        _selectedProjectIds.clear();
      });
      final notifier = ref.read(projectProvider.notifier);
      for (final id in ids) {
        await notifier.updateStatus(id, status);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Projects updated to ${status.displayName}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final projectsAsync = ref.watch(projectProvider);
    final currency = ref.watch(currencyProvider);
    final isClient = ref.watch(settingsProvider).isClientMode;
    final clients = ref.watch(safeClientsProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20.0,
        leading: _isSelectMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSelectMode = false;
                    _selectedProjectIds.clear();
                  });
                },
              )
            : null,
        title: _isSelectMode
            ? Text(
                '${_selectedProjectIds.length} Selected',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                ),
              )
            : Text(
                'Projects',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                ),
              ),
        actions: [
          if (_isSelectMode) ...[
            IconButton(
              icon: const Icon(CupertinoIcons.checkmark_seal_fill),
              tooltip: 'Update Status',
              onPressed: _selectedProjectIds.isEmpty ? null : _handleBatchStatusUpdate,
            ),
            IconButton(
              icon: const Icon(CupertinoIcons.delete),
              tooltip: 'Delete Projects',
              onPressed: _selectedProjectIds.isEmpty ? null : _handleBatchDelete,
            ),
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: 'Select All',
              onPressed: () {
                final projects = projectsAsync.valueOrNull ?? [];
                setState(() {
                  _selectedProjectIds.addAll(projects.map((p) => p.id));
                });
              },
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.playlist_add_check_rounded),
              tooltip: 'Select Multiple',
              onPressed: () {
                setState(() {
                  _isSelectMode = true;
                  _selectedProjectIds.clear();
                });
              },
            ),
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
              onPressed: () {
                if (!isClient && clients.isEmpty) {
                  if (PremiumHelper.checkClientLimit(ref, context)) {
                    context.push('/add-client');
                  }
                } else {
                  if (PremiumHelper.checkProjectLimit(ref, context)) {
                    context.push('/projects/add');
                  }
                }
              },
            ),
          ],
          const SizedBox(width: 16),
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
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(projectProvider);
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: projectsAsync.when(
              loading: () => LoadingWidget(message: 'Loading projects...'),
              error: (e, _) => ErrorStateWidget(
                message: e.toString(),
                onRetry: () => ref.read(projectProvider.notifier).refresh(),
              ),
              data: (projects) {
                final searchFiltered = projects
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
                  return deadlineDate.isBefore(today) && p.status != ProjectStatus.paid;
                }).length;

                // Apply selected filter chip
                final filtered = searchFiltered.where((p) {
                  switch (_selectedFilter) {
                    case ProjectListFilter.active:
                      return p.status == ProjectStatus.yetToStart ||
                          p.status == ProjectStatus.inProgress ||
                          p.status == ProjectStatus.revisionPending;
                    case ProjectListFilter.overdue:
                      if (p.deadline == null) return false;
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      final deadlineDate = DateTime(p.deadline!.year, p.deadline!.month, p.deadline!.day);
                      return deadlineDate.isBefore(today) && p.status != ProjectStatus.paid;
                    case ProjectListFilter.completed:
                      return p.status == ProjectStatus.completed ||
                          p.status == ProjectStatus.paid;
                    case ProjectListFilter.all:
                      return true;
                  }
                }).toList();

                if (projects.isEmpty) {
                  if (!isClient && clients.isEmpty) {
                    return EmptyStateWidget(
                      key: const ValueKey('empty_no_clients'),
                      icon: Icons.people_outline,
                      title: 'No clients yet',
                      subtitle: 'Add a client first to create a project under them.',
                      actionLabel: 'Add Client',
                      onAction: () => context.push('/add-client'),
                    );
                  }

                  return EmptyStateWidget(
                    key: const ValueKey('empty_no_projects'),
                    icon: Icons.folder,
                    title: 'No projects yet',
                    subtitle: isClient ? 'Assign your first project' : 'Create your first project',
                    actionLabel: isClient ? 'Assign Project' : 'Add Project',
                    onAction: () {
                      if (PremiumHelper.checkProjectLimit(ref, context)) {
                        context.push('/projects/add');
                      }
                    },
                  );
                }

                return Column(
                  key: const ValueKey('projects_list_column'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildSummaryChip(
                              label: 'All (${projects.length})',
                              color: isDark ? Colors.white70 : const Color(0xFF64748B),
                              isDark: isDark,
                              isSelected: _selectedFilter == ProjectListFilter.all,
                              onTap: () => setState(() => _selectedFilter = ProjectListFilter.all),
                            ),
                            const SizedBox(width: 8),
                            _buildSummaryChip(
                              label: '$activeCount Active',
                              color: AppColors.primary,
                              isDark: isDark,
                              isSelected: _selectedFilter == ProjectListFilter.active,
                              onTap: () => setState(() => _selectedFilter = ProjectListFilter.active),
                            ),
                            const SizedBox(width: 8),
                            _buildSummaryChip(
                              label: '$overdueCount Overdue',
                              color: AppColors.error,
                              isDark: isDark,
                              isSelected: _selectedFilter == ProjectListFilter.overdue,
                              onTap: () => setState(() => _selectedFilter = ProjectListFilter.overdue),
                            ),
                            const SizedBox(width: 8),
                            _buildSummaryChip(
                              label: '$completedCount Completed',
                              color: const Color(0xFF22C55E),
                              isDark: isDark,
                              isSelected: _selectedFilter == ProjectListFilter.completed,
                              onTap: () => setState(() => _selectedFilter = ProjectListFilter.completed),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filtered.isEmpty
                          ? EmptyStateWidget(
                              icon: Icons.folder,
                              title: 'No projects found',
                              subtitle: 'Try a different search or filter',
                              actionLabel: isClient ? 'Assign Project' : 'Add Project',
                              onAction: () {
                                if (PremiumHelper.checkProjectLimit(ref, context)) {
                                  context.push('/projects/add');
                                }
                              },
                            )
                          : () {
                              final columns = AppLayout.gridColumns(context);
                              if (columns > 1) {
                                return GridView.builder(
                                  padding: EdgeInsets.all(AppSpacing.pageHorizontal),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    mainAxisSpacing: AppSpacing.sm,
                                    crossAxisSpacing: AppSpacing.sm,
                                    childAspectRatio: columns == 2 ? 1.6 : 1.8,
                                  ),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final project = filtered[index];
                                    final isSelected = _selectedProjectIds.contains(project.id);
                                    return AnimatedListItem(
                                      key: ValueKey(project.id),
                                      index: index,
                                      child: ProjectCard(
                                        project: project,
                                        currency: currency,
                                        isSelectMode: _isSelectMode,
                                        isSelected: isSelected,
                                        onSelectedChanged: (val) {
                                          setState(() {
                                            if (val == true) {
                                              _selectedProjectIds.add(project.id);
                                            } else {
                                              _selectedProjectIds.remove(project.id);
                                            }
                                          });
                                        },
                                        onTap: () {
                                          if (_isSelectMode) {
                                            setState(() {
                                              if (isSelected) {
                                                _selectedProjectIds.remove(project.id);
                                              } else {
                                                _selectedProjectIds.add(project.id);
                                              }
                                            });
                                          } else {
                                            context.push('/projects/${project.id}');
                                          }
                                        },
                                      ),
                                    );
                                  },
                                );
                              }
                              return ListView.builder(
                                padding: EdgeInsets.all(AppSpacing.pageHorizontal),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final project = filtered[index];
                                  final isSelected = _selectedProjectIds.contains(project.id);
                                  return AnimatedListItem(
                                    key: ValueKey(project.id),
                                    index: index,
                                    child: Padding(
                                      padding: EdgeInsets.only(bottom: AppSpacing.sm),
                                      child: ProjectCard(
                                        project: project,
                                        currency: currency,
                                        isSelectMode: _isSelectMode,
                                        isSelected: isSelected,
                                        onSelectedChanged: (val) {
                                          setState(() {
                                            if (val == true) {
                                              _selectedProjectIds.add(project.id);
                                            } else {
                                              _selectedProjectIds.remove(project.id);
                                            }
                                          });
                                        },
                                        onTap: () {
                                          if (_isSelectMode) {
                                            setState(() {
                                              if (isSelected) {
                                                _selectedProjectIds.remove(project.id);
                                              } else {
                                                _selectedProjectIds.add(project.id);
                                              }
                                            });
                                          } else {
                                            context.push('/projects/${project.id}');
                                          }
                                        },
                                      ),
                                    ),
                                  );
                                },
                              );
                            }(),
                    ),
                  ],
                );
              },
            ),
            ),
          ),
        ],
      ),
    );
  }
}
