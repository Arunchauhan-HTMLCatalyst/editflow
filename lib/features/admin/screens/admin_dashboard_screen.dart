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
    final analyticsAsync = ref.watch(adminAnalyticsProvider);
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
        final paidUsersCount = stats['paidUsersCount'] ?? 0;
        final unpaidUsersCount = stats['unpaidUsersCount'] ?? 0;
        final monthlySubscribersCount = stats['monthlySubscribersCount'] ?? 0;
        final yearlySubscribersCount = stats['yearlySubscribersCount'] ?? 0;
        final totalEarnings = stats['totalEarnings'] ?? 0;

        return Padding(
          padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
          child: RefreshIndicator(
            onRefresh: () async {
            ref.invalidate(adminStatsProvider);
            ref.invalidate(adminAnalyticsProvider);
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
                  childAspectRatio: isDesktop ? 1.95 : 2.1,
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

                // SUBSCRIPTION & REVENUE OVERVIEW
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SUBSCRIPTION & REVENUE OVERVIEW',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildEarningsCard(totalEarnings)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildSubscribersBreakdownCard(paidUsersCount, unpaidUsersCount, monthlySubscribersCount, yearlySubscribersCount)),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildEarningsCard(totalEarnings),
                          const SizedBox(height: 16),
                          _buildSubscribersBreakdownCard(paidUsersCount, unpaidUsersCount, monthlySubscribersCount, yearlySubscribersCount),
                        ],
                      ),
                    const SizedBox(height: 32),
                  ],
                ),

                // USER REGISTRATION GROWTH BY MONTH
                analyticsAsync.when(
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                  error: (err, _) => const SizedBox(),
                  data: (analyticsData) {
                    final users = analyticsData['users'] as List? ?? [];
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

                    if (sortedMonths.isEmpty) return const SizedBox();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'USER REGISTRATION GROWTH BY MONTH',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border, width: 0.8),
                          ),
                          child: ListView.separated(
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
                                padding: const EdgeInsets.symmetric(vertical: 10.0),
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
                                          minHeight: 8,
                                          backgroundColor: AppColors.border,
                                          valueColor: const AlwaysStoppedAnimation(AppColors.primaryNeon),
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
                        ),
                        const SizedBox(height: 32),
                      ],
                    );
                  },
                ),

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
        ),
      );
    },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1,
        ),
        gradient: LinearGradient(
          colors: [
            AppColors.card,
            color.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsCard(num totalEarnings) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.8),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.primaryNeon.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOTAL SUBSCRIPTION REVENUE',
            style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
          const SizedBox(height: 12),
          Text(
            '₹${NumberFormat('#,##,###').format(totalEarnings)}',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Outfit'),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscribersBreakdownCard(int paid, int unpaid, int monthly, int yearly) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Paid / Premium Users', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text('$paid', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const Divider(color: AppColors.border, height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Unpaid / Free Users', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text('$unpaid', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const Divider(color: AppColors.border, height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Plan Split (Monthly / Yearly)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text('$monthly / $yearly', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryNeon)),
            ],
          ),
        ],
      ),
    );
  }
}
