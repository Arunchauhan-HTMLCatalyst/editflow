import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/admin_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  String _formatBytes(num bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

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

        final totalUsers = stats['totalUsers'] ?? 0;
        final activeUsers = stats['activeUsers'] ?? 0;
        final newUsers = stats['newUsers'] ?? 0;
        final totalProjects = stats['totalProjects'] ?? 0;
        final totalClients = stats['totalClients'] ?? 0;
        final totalReviews = stats['totalReviews'] ?? 0;
        final totalStorage = stats['totalStorageUsed'] ?? 0;
        final dau = stats['dau'] ?? 0;
        final mau = stats['mau'] ?? 0;

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
                      'STORAGE USED',
                      _formatBytes(totalStorage),
                      Icons.storage_rounded,
                      AppColors.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Second Row Metrics
                GridView.count(
                  crossAxisCount: isDesktop ? 4 : (MediaQuery.of(context).size.width > 600 ? 2 : 1),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: isDesktop ? 1.4 : 1.6,
                  children: [
                    _buildStatCard(
                      'TOTAL PROJECTS',
                      totalProjects.toString(),
                      Icons.folder_copy_rounded,
                      Colors.cyan,
                    ),
                    _buildStatCard(
                      'TOTAL CLIENTS',
                      totalClients.toString(),
                      Icons.handshake_rounded,
                      Colors.purple,
                    ),
                    _buildStatCard(
                      'TOTAL REVIEWS',
                      totalReviews.toString(),
                      Icons.rate_review_rounded,
                      Colors.pinkAccent,
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

                // Recent Activities Title
                const Text(
                  'RECENT SYSTEM ACTIVITIES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),

                // Activities Table/List
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
                        'No recent platform activities detected.',
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
}
