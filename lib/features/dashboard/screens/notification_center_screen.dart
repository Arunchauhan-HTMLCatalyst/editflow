import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/computed_providers.dart';
import '../../../shared/widgets/ambient_glow_container.dart';
import '../../../shared/widgets/empty_state.dart';

class NotificationCenterScreen extends ConsumerWidget {
  final bool isDialog;
  const NotificationCenterScreen({super.key, this.isDialog = false});

  IconData _getIconForType(String type) {
    switch (type) {
      case 'comment_created':
        return CupertinoIcons.chat_bubble_2_fill;
      case 'payment_overdue':
        return CupertinoIcons.money_dollar_circle_fill;
      case 'due_date_overdue':
        return CupertinoIcons.exclamationmark_triangle_fill;
      case 'due_date_12h':
      case 'due_date_1d':
      case 'due_date_2d':
        return CupertinoIcons.alarm_fill;
      case 'project_created':
        return CupertinoIcons.folder_badge_plus;
      case 'client_created':
        return CupertinoIcons.person_crop_circle_fill_badge_plus;
      default:
        return CupertinoIcons.bell_fill;
    }
  }

  Color _getColorForType(String type, bool isDark) {
    switch (type) {
      case 'comment_created':
        return AppColors.primary;
      case 'payment_overdue':
      case 'due_date_overdue':
        return AppColors.error;
      case 'due_date_12h':
      case 'due_date_1d':
      case 'due_date_2d':
        return const Color(0xFFF59E0B);
      case 'project_created':
      case 'client_created':
        return const Color(0xFF22C55E);
      default:
        return isDark ? AppColors.textSecondary : const Color(0xFF64748B);
    }
  }

  String _formatTimeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays > 7) {
      return DateFormat('MMM d, yyyy').format(dt);
    } else if (diff.inDays >= 1) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours >= 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes >= 1) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activityAsync = ref.watch(recentActivityProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            child: Container(
              padding: const EdgeInsets.all(6.0),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                  width: 0.8,
                ),
              ),
              child: Icon(
                isDialog ? CupertinoIcons.clear : CupertinoIcons.back,
                size: 18,
                color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
              ),
            ),
            onPressed: () => context.pop(),
          ),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
          ),
        ),
        actions: [
          activityAsync.maybeWhen(
            data: (list) {
              if (list.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: TextButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await ref.read(recentActivityProvider.notifier).clearAll();
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Notifications cleared successfully')),
                      );
                    } catch (e) {
                      debugPrint('Failed to clear notifications: $e');
                      messenger.showSnackBar(
                        SnackBar(content: Text('Failed to clear: $e')),
                      );
                    }
                  },
                  child: const Text(
                    'Clear All',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: AmbientGlowContainer(
        child: SafeArea(
          child: activityAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (err, _) => Center(
              child: Text(
                'Failed to load notifications: $err',
                style: const TextStyle(color: AppColors.error),
              ),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const EmptyStateWidget(
                  icon: CupertinoIcons.bell_slash,
                  title: 'No new notifications',
                  subtitle: 'Recent project activities and alerts will show up here.',
                );
              }

              return RefreshIndicator(
                onRefresh: () => ref.refresh(recentActivityProvider.future),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    final color = _getColorForType(item.type, isDark);
                    final icon = _getIconForType(item.type);

                    return InkWell(
                      onTap: () {
                        if (item.type == 'payment_overdue' && item.referenceId == 'combined_overdue_payments') {
                          context.go('/payments');
                        } else if (item.referenceId != null && item.referenceType == 'project') {
                          context.push('/projects/${item.referenceId}');
                        }
                      },
                      borderRadius: BorderRadius.circular(16.0),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, color: color, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.description,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.textPrimary : const Color(0xFF1E293B),
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTimeAgo(item.createdAt.toLocal()),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (item.referenceId != null && item.referenceType == 'project')
                              const Icon(CupertinoIcons.chevron_right, size: 14, color: AppColors.textMuted),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
