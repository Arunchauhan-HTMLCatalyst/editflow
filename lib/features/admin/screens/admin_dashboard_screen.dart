import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/admin_provider.dart';
import '../services/admin_service.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text('Error loading stats: $err', style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(adminStatsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (data) {
        final stats = data['stats'] as Map<String, dynamic>? ?? {};
        final activities = data['recentActivity'] as List? ?? [];
        final supportRequests = data['supportRequests'] as List? ?? [];

        final totalUsers = stats['totalUsers'] ?? 0;
        final activeUsers = stats['activeUsers'] ?? 0;
        final newUsers = stats['newUsers'] ?? 0;
        final dau = stats['dau'] ?? 0;
        final mau = stats['mau'] ?? 0;
        final dailyNewUsers = stats['dailyNewUsers'] as List? ?? [];

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(adminStatsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Metrics Grid
                GridView.count(
                  crossAxisCount: isDesktop ? 4 : (MediaQuery.of(context).size.width > 600 ? 2 : 1),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: isDesktop ? 1.4 : 1.6,
                  children: [
                    _buildStatCard(
                      'TOTAL USERS',
                      totalUsers.toString(),
                      Icons.people_alt_rounded,
                      AppColors.primary,
                    ),
                    _buildStatCard(
                      'ACTIVE USERS',
                      activeUsers.toString(),
                      Icons.check_circle_rounded,
                      AppColors.success,
                    ),
                    _buildStatCard(
                      'NEW USERS (30D)',
                      newUsers.toString(),
                      Icons.person_add_rounded,
                      AppColors.info,
                    ),
                    _buildStatCard(
                      'ACTIVE USERS (DAU/MAU)',
                      '$dau / $mau',
                      Icons.insights_rounded,
                      AppColors.primaryNeon,
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Pending Support Requests
                Builder(
                  builder: (context) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PENDING SUPPORT REQUESTS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Colors.orangeAccent,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (supportRequests.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border, width: 0.8),
                            ),
                            child: const Center(
                              child: Text(
                                'No pending support requests',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              ),
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border, width: 0.8),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: supportRequests.length,
                              separatorBuilder: (context, idx) => const Divider(height: 1, color: AppColors.border),
                              itemBuilder: (context, idx) {
                                final ticket = supportRequests[idx] as Map<String, dynamic>;
                                final ticketId = ticket['id'] as String;
                                final targetUserId = ticket['user_id'] as String;
                                final description = ticket['description'] as String? ?? 'No description';
                                final createdAtStr = ticket['created_at'] as String;
                                final profile = ticket['profiles'] as Map<String, dynamic>?;
                                final fullName = profile?['full_name'] as String? ?? 'Unknown User';
                                final email = profile?['email'] as String? ?? '';
                                
                                final dt = DateTime.tryParse(createdAtStr)?.toLocal();
                                final formattedTime = dt != null ? DateFormat('MMM d, h:mm a').format(dt) : 'N/A';

                                return Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  fullName,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                ),
                                                if (email.isNotEmpty)
                                                  Text(
                                                    email,
                                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            formattedTime,
                                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Text(
                                            'User ID: ',
                                            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                          ),
                                          Expanded(
                                            child: Text(
                                              targetUserId,
                                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'monospace'),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          InkWell(
                                            onTap: () {
                                              Clipboard.setData(ClipboardData(text: targetUserId));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('User ID copied to clipboard!')),
                                              );
                                            },
                                            child: const Icon(Icons.copy_rounded, size: 12, color: AppColors.primaryNeon),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.black12,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                                        ),
                                        child: Text(
                                          description,
                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () => _handleSupportAction(context, ref, ticketId, targetUserId, 'reject'),
                                            icon: const Icon(Icons.close_rounded, size: 14, color: AppColors.error),
                                            label: const Text('Reject', style: TextStyle(fontSize: 11, color: AppColors.error)),
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(color: AppColors.error, width: 0.8),
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          ElevatedButton.icon(
                                            onPressed: () => _handleSupportAction(context, ref, ticketId, targetUserId, 'accept'),
                                            icon: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                                            label: const Text('Accept', style: TextStyle(fontSize: 11, color: Colors.white)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary,
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Layout breakdown: Daily New Users and Recent activities
                Builder(
                  builder: (context) {
                    final dailyNewUsersWidget = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'NEWLY REGISTERED USERS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border, width: 0.8),
                          ),
                          child: dailyNewUsers.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: Center(
                                    child: Text('No new users found.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: dailyNewUsers.length,
                                  separatorBuilder: (context, index) => const Divider(color: AppColors.border, height: 1),
                                  itemBuilder: (context, idx) {
                                    final entry = dailyNewUsers[idx] as Map<String, dynamic>;
                                    final uid = entry['id'] as String? ?? '';
                                    final name = entry['full_name'] as String? ?? 'User';
                                    final email = entry['email'] as String? ?? '';
                                    final createdAtStr = entry['created_at'] as String? ?? '';

                                    String formattedTime = '';
                                    if (createdAtStr.isNotEmpty) {
                                      final dt = DateTime.parse(createdAtStr);
                                      formattedTime = DateFormat('yyyy-MM-dd HH:mm').format(dt.toLocal());
                                    }

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: AppColors.success.withValues(alpha: 0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.person_add_rounded, color: AppColors.success, size: 14),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        name,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    InkWell(
                                                      onTap: () {
                                                        Clipboard.setData(ClipboardData(text: uid));
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text('User ID copied to clipboard!')),
                                                        );
                                                      },
                                                      child: const Icon(Icons.copy_rounded, size: 10, color: AppColors.primaryNeon),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  email,
                                                  style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            formattedTime,
                                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );

                    final recentActivitiesWidget = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'RECENT AUDIT LOGS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (activities.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border, width: 0.8),
                            ),
                            child: const Center(
                              child: Text(
                                'No recent audit logs detected.',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                              ),
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border, width: 0.8),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: activities.length,
                              separatorBuilder: (context, index) => const Divider(color: AppColors.border, height: 1),
                              itemBuilder: (context, idx) {
                                final act = activities[idx] as Map<String, dynamic>;
                                final type = act['type'] as String? ?? 'activity';
                                final description = act['description'] as String? ?? '';
                                final dt = DateTime.parse(act['created_at'] as String);
                                final formattedTime = DateFormat('yyyy-MM-dd HH:mm').format(dt.toLocal());

                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.flash_on_rounded, color: AppColors.primaryNeon, size: 14),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              description,
                                              style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Type: ${type.toUpperCase()}',
                                              style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        formattedTime,
                                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    );

                    if (isDesktop) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 4, child: dailyNewUsersWidget),
                          const SizedBox(width: 24),
                          Expanded(flex: 6, child: recentActivitiesWidget),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          dailyNewUsersWidget,
                          const SizedBox(height: 32),
                          recentActivitiesWidget,
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: AppColors.border,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSupportAction(
    BuildContext context,
    WidgetRef ref,
    String ticketId,
    String targetUserId,
    String action,
  ) async {
    final responseController = TextEditingController(
      text: action == 'accept'
          ? 'Your support request has been accepted. We are investigating your issue.'
          : 'Your support request has been rejected.',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          title: Text(
            action == 'accept' ? 'Accept Support Ticket' : 'Reject Support Ticket',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add message feedback response to send to user:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: responseController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(8),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: action == 'accept' ? AppColors.primary : AppColors.error,
              ),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await AdminService.invokeAdminAction('handle_support_ticket', {
                    'ticketId': ticketId,
                    'action': action,
                    'targetUserId': targetUserId,
                    'feedback': responseController.text.trim(),
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Support request successfully ${action}ed!')),
                    );
                  }
                  ref.invalidate(adminStatsProvider);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update ticket: $e')),
                    );
                  }
                }
              },
              child: Text(action == 'accept' ? 'Accept' : 'Reject', style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
