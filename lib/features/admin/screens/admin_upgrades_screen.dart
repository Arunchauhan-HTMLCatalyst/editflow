import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/admin_provider.dart';
import '../services/admin_service.dart';

class AdminUpgradesScreen extends ConsumerStatefulWidget {
  const AdminUpgradesScreen({super.key});

  @override
  ConsumerState<AdminUpgradesScreen> createState() => _AdminUpgradesScreenState();
}

class _AdminUpgradesScreenState extends ConsumerState<AdminUpgradesScreen> {
  String _statusFilter = 'pending'; // 'all', 'pending', 'approved', 'rejected'

  Future<void> _processUpgrade(String requestId, String duration) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.primaryNeon)),
      );

      await AdminService.invokeAdminAction('approve_premium_upgrade', {
        'requestId': requestId,
        'duration': duration,
      });

      if (mounted) {
        Navigator.pop(context); // Close loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Successfully upgraded user account to $duration plan!'),
          ),
        );
        ref.invalidate(adminUpgradeRequestsProvider);
        ref.invalidate(adminStatsProvider);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Error upgrading account: $e'),
          ),
        );
      }
    }
  }

  Future<void> _rejectUpgrade(String requestId) async {
    final feedbackController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border, width: 0.8),
          ),
          title: const Text('Reject Upgrade Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Please provide a feedback description outlining why this upgrade request was rejected (e.g. invalid UTR number, payment not matching, etc.).',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: feedbackController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Rejection Reason / Feedback',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    hintText: 'e.g. Transaction Reference number (UTR) not found in bank accounts.',
                    border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Rejection feedback reason is required';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final reason = feedbackController.text.trim();
                Navigator.pop(context); // Close dialog

                try {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.primaryNeon)),
                  );

                  await AdminService.invokeAdminAction('reject_premium_upgrade', {
                    'requestId': requestId,
                    'feedback': reason,
                  });

                  if (mounted) {
                    Navigator.pop(context); // Close loading indicator
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.success,
                        content: Text('Upgrade request rejected. User has been notified.'),
                      ),
                    );
                    ref.invalidate(adminUpgradeRequestsProvider);
                    ref.invalidate(adminStatsProvider);
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context); // Close loading indicator
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.error,
                        content: Text('Error rejecting request: $e'),
                      ),
                    );
                  }
                }
              },
              child: const Text('Reject Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showApproveConfirmation(String requestId, String requestedPlan) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border, width: 0.8),
          ),
          title: const Text('Select Upgrade Expiry Duration', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Requested plan is ${requestedPlan.toUpperCase()}. Select how long you want to grant premium access for this transaction:',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
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
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(context);
                _processUpgrade(requestId, 'monthly');
              },
              child: const Text('Monthly (30 Days)', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNeon,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(context);
                _processUpgrade(requestId, 'yearly');
              },
              child: const Text('Yearly (365 Days)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final upgradesAsync = ref.watch(adminUpgradeRequestsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: upgradesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryNeon)),
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.error))),
        data: (requests) {
          final filtered = requests.where((r) {
            if (_statusFilter == 'all') return true;
            return r['status'] == _statusFilter;
          }).toList();

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PREMIUM UPGRADE REQUESTS',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Verify manual payment transfers and activate subscription upgrades',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.card,
                        side: const BorderSide(color: AppColors.border, width: 0.8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => ref.invalidate(adminUpgradeRequestsProvider),
                      icon: const Icon(Icons.refresh_rounded, size: 14, color: AppColors.primaryNeon),
                      label: const Text('Refresh', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Plan status filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['pending', 'approved', 'rejected', 'all'].map((filter) {
                      final isSelected = _statusFilter == filter;
                      final count = requests.where((r) => r['status'] == filter || filter == 'all').length;

                      return Padding(
                        padding: const EdgeInsets.only(right: 10.0),
                        child: ChoiceChip(
                          label: Text(
                            '${filter.toUpperCase()} ($count)',
                            style: TextStyle(
                              color: isSelected ? Colors.black : AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppColors.primaryNeon,
                          backgroundColor: AppColors.card,
                          side: BorderSide(color: isSelected ? AppColors.primaryNeon : AppColors.border, width: 0.8),
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                _statusFilter = filter;
                              });
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // Requests card lists
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.star_outline_rounded, size: 48, color: AppColors.textMuted),
                              const SizedBox(height: 16),
                              Text(
                                'No ${_statusFilter.toUpperCase()} requests found',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, idx) {
                            final req = filtered[idx];
                            final id = req['id'] as String;
                            final userProfile = req['profiles'] as Map? ?? {};
                            final fullName = userProfile['full_name'] as String? ?? 'User';
                            final email = userProfile['email'] as String? ?? '';
                            final planType = req['plan_type'] as String? ?? 'monthly';
                            final utr = req['utr'] as String? ?? '';
                            final status = req['status'] as String? ?? 'pending';
                            final feedback = req['feedback'] as String? ?? '';
                            final createdAtStr = req['created_at'] as String;
                            final date = DateFormat('MMM d, yyyy • hh:mm a').format(DateTime.parse(createdAtStr));

                            final isPending = status == 'pending';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isPending ? AppColors.border : Colors.transparent,
                                  width: 0.8,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: planType == 'yearly'
                                                  ? AppColors.primaryNeon.withValues(alpha: 0.12)
                                                  : AppColors.primary.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '${planType.toUpperCase()} PLAN',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                                color: planType == 'yearly' ? AppColors.primaryNeon : AppColors.primary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: status == 'approved'
                                                  ? AppColors.success.withValues(alpha: 0.12)
                                                  : status == 'rejected'
                                                      ? AppColors.error.withValues(alpha: 0.12)
                                                      : Colors.amber.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              status.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                                color: status == 'approved'
                                                    ? AppColors.success
                                                    : status == 'rejected'
                                                        ? AppColors.error
                                                        : Colors.amber,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(date, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    fullName,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(email, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  const SizedBox(height: 12),
                                  const Divider(color: AppColors.border, height: 1),
                                  const SizedBox(height: 12),

                                  // UTR Reference number detail card
                                  Row(
                                    children: [
                                      const Icon(Icons.qr_code_scanner_rounded, size: 14, color: AppColors.textMuted),
                                      const SizedBox(width: 6),
                                      const Text('UTR reference No:', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                      const SizedBox(width: 8),
                                      Text(
                                        utr,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Courier'),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () {
                                          Clipboard.setData(ClipboardData(text: utr));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('UTR copied to clipboard!')),
                                          );
                                        },
                                        child: const Icon(Icons.copy_rounded, size: 12, color: AppColors.primaryNeon),
                                      ),
                                    ],
                                  ),

                                  if (status == 'rejected' && feedback.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.error.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.error.withValues(alpha: 0.1), width: 0.8),
                                      ),
                                      child: Text(
                                        'Rejection Feedback: $feedback',
                                        style: const TextStyle(fontSize: 12, color: AppColors.error),
                                      ),
                                    ),
                                  ],

                                  if (isPending) ...[
                                    const SizedBox(height: 18),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          style: TextButton.styleFrom(foregroundColor: AppColors.error),
                                          onPressed: () => _rejectUpgrade(id),
                                          icon: const Icon(Icons.close_rounded, size: 14),
                                          label: const Text('Reject Payment', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 12),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primaryNeon,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: () => _showApproveConfirmation(id, planType),
                                          icon: const Icon(Icons.check_rounded, size: 14),
                                          label: const Text('Approve Upgrade', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
