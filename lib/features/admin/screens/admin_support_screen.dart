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

                        // Parse description components
                        String category = 'Support';
                        String subject = 'No Subject';
                        String body = description;
                        String deviceInfo = '';
                        String appVersion = '';

                        final catMatch = RegExp(r'^\[([^\]]+)\]').firstMatch(description);
                        if (catMatch != null) {
                          category = catMatch.group(1) ?? 'Support';
                        }

                        final lines = description.split('\n');
                        List<String> bodyLines = [];
                        bool parsingBody = false;

                        for (final line in lines) {
                          if (line.startsWith('Subject: ')) {
                            subject = line.replaceFirst('Subject: ', '');
                          } else if (line.startsWith('Description: ')) {
                            bodyLines.add(line.replaceFirst('Description: ', ''));
                            parsingBody = true;
                          } else if (line.startsWith('Device: ')) {
                            deviceInfo = line.replaceFirst('Device: ', '');
                            parsingBody = false;
                          } else if (line.startsWith('App Version: ')) {
                            appVersion = line.replaceFirst('App Version: ', '');
                            parsingBody = false;
                          } else if (parsingBody) {
                            bodyLines.add(line);
                          }
                        }

                        if (bodyLines.isNotEmpty) {
                          body = bodyLines.join('\n');
                        } else {
                          body = description;
                        }

                        // Determine category tag color
                        Color tagColor;
                        switch (category.toLowerCase()) {
                          case 'account':
                            tagColor = Colors.blueAccent;
                            break;
                          case 'projects':
                            tagColor = Colors.purpleAccent;
                            break;
                          case 'payments & invoices':
                          case 'payments':
                            tagColor = Colors.greenAccent;
                            break;
                          case 'video reviews':
                            tagColor = Colors.orangeAccent;
                            break;
                          case 'security':
                            tagColor = Colors.redAccent;
                            break;
                          default:
                            tagColor = AppColors.primaryNeon;
                        }

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
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                            child: Text(
                                              fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  fullName,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                                ),
                                                if (email.isNotEmpty)
                                                  Text(
                                                    email,
                                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          formattedTime,
                                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: tagColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: tagColor.withValues(alpha: 0.25), width: 0.5),
                                          ),
                                          child: Text(
                                            category.toUpperCase(),
                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: tagColor),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                const Divider(color: AppColors.border, height: 1),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    const Icon(Icons.label_important_outline_rounded, size: 16, color: AppColors.primaryNeon),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        subject,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    body,
                                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.45),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
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
                                            child: const Icon(Icons.copy_rounded, size: 12, color: AppColors.primaryNeon),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (deviceInfo.isNotEmpty || appVersion.isNotEmpty)
                                      Text(
                                        '${deviceInfo.isNotEmpty ? deviceInfo : ''}${deviceInfo.isNotEmpty && appVersion.isNotEmpty ? ' • ' : ''}${appVersion.isNotEmpty ? 'App $appVersion' : ''}',
                                        style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                      ),
                                  ],
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
          ? 'Your support request has been accepted. Our engineering team is currently investigating your ticket. We will reach out to you via your registered email address shortly. Thank you for your patience!'
          : 'Your support request has been rejected. This category of request is not supported at this time, or does not contain sufficient details. Please review our FAQ section or submit another ticket with more details.',
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
                Navigator.pop(context); // Close input dialog

                // Show loading overlay
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(color: AppColors.primaryNeon),
                  ),
                );

                try {
                  await AdminService.invokeAdminAction('handle_support_ticket', {
                    'ticketId': ticketId,
                    'action': action,
                    'targetUserId': targetUserId,
                    'feedback': responseController.text.trim(),
                  });

                  // Invalidate the provider and await the refetch to complete
                  ref.invalidate(adminStatsProvider);
                  await ref.read(adminStatsProvider.future);

                  if (context.mounted) {
                    Navigator.pop(context); // Pop loading spinner
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Support request successfully ${action}ed! Client has been notified.',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: action == 'accept' ? AppColors.success : AppColors.error,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context); // Pop loading spinner
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
