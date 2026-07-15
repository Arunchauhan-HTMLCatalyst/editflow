import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/admin_provider.dart';

class AdminAnalyticsScreen extends ConsumerWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(adminAnalyticsProvider);
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return analyticsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.textSecondary))),
      data: (data) {
        final projects = data['projects'] as List? ?? [];
        final users = data['users'] as List? ?? [];

        // Calculate Project Status distribution
        final Map<String, int> statusCounts = {
          'yet_to_start': 0,
          'in_progress': 0,
          'revision_pending': 0,
          'completed': 0,
          'paid': 0,
        };

        for (final p in projects) {
          final s = p['status'] as String? ?? 'yet_to_start';
          statusCounts[s] = (statusCounts[s] ?? 0) + 1;
        }

        final totalProjects = projects.length;

        // Calculate User Signup Growth by Month
        final Map<String, int> signupMonths = {};
        for (final u in users) {
          final createdStr = u['created_at'] as String?;
          if (createdStr != null) {
            final dt = DateTime.parse(createdStr);
            final monthStr = '${dt.year}-${dt.month.toString().padLeft(2, "0")}';
            signupMonths[monthStr] = (signupMonths[monthStr] ?? 0) + 1;
          }
        }

        final sortedMonths = signupMonths.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(adminAnalyticsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Project Pipeline Distribution
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border, width: 0.8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PROJECT STATUS DISTRIBUTION',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 20),
                            ...statusCounts.entries.map((e) {
                              final status = e.key;
                              final count = e.value;
                              final ratio = totalProjects > 0 ? (count / totalProjects).clamp(0.0, 1.0) : 0.0;
                              final percentage = (ratio * 100).toStringAsFixed(1);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          status.toUpperCase().replaceAll('_', ' '),
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                        Text(
                                          '$count projects ($percentage%)',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryNeon),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: ratio,
                                        minHeight: 8,
                                        backgroundColor: AppColors.border,
                                        valueColor: AlwaysStoppedAnimation(
                                          status == 'paid' ? AppColors.primaryNeon : (status == 'completed' ? AppColors.success : AppColors.primary),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),

                    if (isDesktop) const SizedBox(width: 24),

                    // Right Column: User Growth Analytics
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border, width: 0.8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'USER REGISTRATION GROWTH BY MONTH',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 20),
                            if (sortedMonths.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 40.0),
                                  child: Text('No registration records found.', style: TextStyle(color: AppColors.textMuted)),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: sortedMonths.length,
                                separatorBuilder: (context, index) => const Divider(color: AppColors.border, height: 1),
                                itemBuilder: (context, idx) {
                                  final item = sortedMonths[idx];
                                  final month = item.key;
                                  final count = item.value;
                                  final maxMonthCount = sortedMonths.map((m) => m.value).reduce((a, b) => a > b ? a : b);
                                  final ratio = maxMonthCount > 0 ? (count / maxMonthCount).clamp(0.0, 1.0) : 0.0;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 80,
                                          child: Text(
                                            month,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                        ),
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: ratio,
                                              minHeight: 12,
                                              backgroundColor: AppColors.border,
                                              valueColor: const AlwaysStoppedAnimation(AppColors.info),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          '+$count users',
                                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
