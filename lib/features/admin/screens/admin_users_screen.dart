import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/admin_provider.dart';
import '../services/admin_service.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;

  Future<void> _triggerUserAction(String userId, String actionName, [String? targetRole]) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${actionName.substring(0, 1).toUpperCase()}${actionName.substring(1)} User?'),
        content: Text('Are you sure you want to $actionName this user account?${actionName == 'delete' ? ' This action cannot be undone.' : ''}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: actionName == 'delete' || actionName == 'suspend' ? AppColors.error : AppColors.primaryNeon,
            ),
            child: Text(actionName.toUpperCase()),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _isLoading = true;
      });

      try {
        await AdminService.invokeAdminAction('user_action', {
          'targetUserId': userId,
          'userAction': actionName,
          if (targetRole != null) 'targetRole': targetRole,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('User action $actionName executed successfully!')),
          );
          ref.invalidate(adminUsersProvider(_searchQuery));
          ref.invalidate(adminStatsProvider);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to execute action: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider(_searchQuery));
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 0.8),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim();
                  });
                },
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  icon: Icon(Icons.search, color: AppColors.textMuted, size: 20),
                  hintText: 'Search users by name or email...',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Users List
            Expanded(
          child: usersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.textSecondary))),
            data: (users) {
              if (users.isEmpty) {
                return const Center(
                  child: Text('No users match your search query.', style: TextStyle(color: AppColors.textMuted)),
                );
              }

              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final u = users[index];
                  final userId = u['id'] as String;
                  final fullName = u['full_name'] as String? ?? 'User';
                  final email = u['email'] as String? ?? '';
                  final role = u['role'] as String? ?? 'user';
                  final isSuspended = u['is_suspended'] as bool? ?? false;
                  final createdAtStr = u['created_at'] as String?;
                  final clientsCount = u['clients'] is Map ? (u['clients']['count'] ?? 0) : 0;
                  final projectsCount = u['projects'] is Map ? (u['projects']['count'] ?? 0) : 0;

                  final joinedDate = createdAtStr != null
                      ? DateFormat('MMM d, yyyy').format(DateTime.parse(createdAtStr))
                      : 'Unknown';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border, width: 0.8),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: role == 'admin' ? Colors.redAccent.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.15),
                          child: Text(
                            fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: role == 'admin' ? Colors.redAccent : AppColors.primaryNeon,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    fullName,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  const SizedBox(width: 8),
                                  // Role Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: role == 'admin' ? Colors.redAccent.withValues(alpha: 0.12) : AppColors.primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      role.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: role == 'admin' ? Colors.redAccent : AppColors.primaryNeon,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Suspension Status Badge
                                  if (isSuspended)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.error.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'SUSPENDED',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(email, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text('Joined: $joinedDate', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Action buttons
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                          onSelected: (val) {
                            if (val == 'suspend') {
                              _triggerUserAction(userId, 'suspend');
                            } else if (val == 'activate') {
                              _triggerUserAction(userId, 'activate');
                            } else if (val == 'promote') {
                              _triggerUserAction(userId, 'change_role', 'admin');
                            } else if (val == 'demote') {
                              _triggerUserAction(userId, 'change_role', 'user');
                            } else if (val == 'delete') {
                              _triggerUserAction(userId, 'delete');
                            }
                          },
                          itemBuilder: (context) => [
                            if (!isSuspended)
                              const PopupMenuItem(
                                value: 'suspend',
                                child: Row(
                                  children: [
                                    Icon(Icons.block, size: 16, color: AppColors.error),
                                    SizedBox(width: 8),
                                    Text('Suspend Account'),
                                  ],
                                ),
                              )
                            else
                              const PopupMenuItem(
                                value: 'activate',
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                                    SizedBox(width: 8),
                                    Text('Activate Account'),
                                  ],
                                ),
                              ),
                            if (role == 'admin')
                              const PopupMenuItem(
                                value: 'demote',
                                child: Row(
                                  children: [
                                    Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
                                    SizedBox(width: 8),
                                    Text('Remove Admin Access'),
                                  ],
                                ),
                              )
                            else
                              const PopupMenuItem(
                                value: 'promote',
                                child: Row(
                                  children: [
                                    Icon(Icons.admin_panel_settings_outlined, size: 16, color: AppColors.primaryNeon),
                                    SizedBox(width: 8),
                                    Text('Promote to Admin'),
                                  ],
                                ),
                              ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                  children: [
                                    Icon(Icons.delete_forever_rounded, size: 16, color: AppColors.error),
                                    SizedBox(width: 8),
                                    Text('Delete User', style: TextStyle(color: AppColors.error)),
                                  ],
                                ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
    if (_isLoading)
      Positioned.fill(
        child: Container(
          color: Colors.black45,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    ],
  );
}
}
