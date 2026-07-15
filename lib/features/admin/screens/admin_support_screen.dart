import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/admin_provider.dart';
import '../services/admin_service.dart';

class AdminSupportScreen extends ConsumerWidget {
  const AdminSupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading tickets: $err', style: const TextStyle(color: AppColors.error)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(adminStatsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) {
          final supportRequests = data['supportRequests'] as List? ?? [];

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminStatsProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PENDING SUPPORT TICKETS',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Manage and respond to support request tickets submitted by users',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  if (supportRequests.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border, width: 0.8),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.support_agent_rounded, size: 48, color: AppColors.textMuted),
                          SizedBox(height: 16),
                          Text(
                            'No Pending Support Tickets',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Requests submitted through settings support form will appear here.',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: supportRequests.length,
                      separatorBuilder: (context, idx) => const SizedBox(height: 16),
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

                        return Container(
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border, width: 0.8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
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
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                                          ),
                                          if (email.isNotEmpty)
                                            Text(
                                              email,
                                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      formattedTime,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
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
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(text: targetUserId));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('User ID copied to clipboard!')),
                                        );
                                      },
                                      child: const Icon(Icons.copy_rounded, size: 13, color: AppColors.primaryNeon),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                                  ),
                                  child: Text(
                                    description,
                                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => _handleSupportAction(context, ref, ticketId, targetUserId, 'reject'),
                                      icon: const Icon(Icons.close_rounded, size: 14, color: AppColors.error),
                                      label: const Text('Reject Request', style: TextStyle(fontSize: 11, color: AppColors.error)),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: AppColors.error, width: 0.8),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    ElevatedButton.icon(
                                      onPressed: () => _handleSupportAction(context, ref, ticketId, targetUserId, 'accept'),
                                      icon: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                                      label: const Text('Accept & Resolve', style: TextStyle(fontSize: 11, color: Colors.white)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          );
        },
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
