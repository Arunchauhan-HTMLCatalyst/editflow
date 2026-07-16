import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/admin_provider.dart';
import '../services/admin_service.dart';

final adminDashboardTabProvider = StateProvider.autoDispose<int>((ref) => 0);

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);
    final analyticsAsync = ref.watch(adminAnalyticsProvider);
    final selectedTab = ref.watch(adminDashboardTabProvider);
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
        final upgradeRequests = data['upgradeRequests'] as List? ?? [];

        final totalUsers = stats['totalUsers'] ?? 0;
        final activeUsers = stats['activeUsers'] ?? 0;
        final totalProjects = stats['totalProjects'] ?? 0;
        final totalClients = stats['totalClients'] ?? 0;
        final totalReviews = stats['totalReviews'] ?? 0;
        final totalComments = stats['totalComments'] ?? 0;
        final totalStorageUsed = stats['totalStorageUsed'] ?? 0; // Bytes

        final dau = stats['dau'] ?? 0;
        final mau = stats['mau'] ?? 0;
        final dailyNewUsers = stats['dailyNewUsers'] as List? ?? [];
        final paidUsersCount = stats['paidUsersCount'] ?? 0;
        final unpaidUsersCount = stats['unpaidUsersCount'] ?? 0;
        final monthlySubscribersCount = stats['monthlySubscribersCount'] ?? 0;
        final yearlySubscribersCount = stats['yearlySubscribersCount'] ?? 0;
        final totalEarnings = stats['totalEarnings'] ?? 0;

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(adminStatsProvider);
            ref.invalidate(adminAnalyticsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Custom Segmented Tab Swiper
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 0.8),
                  ),
                  child: Row(
                    children: [
                      _buildTabButton(ref, 0, 'Overview', Icons.analytics_rounded, selectedTab),
                      _buildTabButton(ref, 1, 'Activity Logs', Icons.receipt_long_rounded, selectedTab),
                      _buildTabButton(ref, 2, 'Pending Tasks', Icons.task_alt_rounded, selectedTab),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Render based on selected tab index
                if (selectedTab == 0) ...[
                  // 1. Overview Tab Metrics Grid
                  GridView.count(
                    crossAxisCount: isDesktop ? 3 : (MediaQuery.of(context).size.width > 600 ? 2 : 1),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: isDesktop ? 2.1 : 2.3,
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
                        'TOTAL PROJECTS',
                        totalProjects.toString(),
                        Icons.workspaces_rounded,
                        AppColors.info,
                      ),
                      _buildStatCard(
                        'TOTAL CLIENTS',
                        totalClients.toString(),
                        Icons.contacts_rounded,
                        AppColors.primaryNeon,
                      ),
                      _buildStatCard(
                        'REVIEWS & COMMENTS',
                        '$totalReviews / $totalComments',
                        Icons.rate_review_rounded,
                        Colors.orange,
                      ),
                      _buildStatCard(
                        'ACTIVE USERS (DAU/MAU)',
                        '$dau / $mau',
                        Icons.insights_rounded,
                        Colors.purple,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // 2. Subscription Revenue Split
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SUBSCRIPTION & REVENUE OVERVIEW',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textSecondary),
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
                      const SizedBox(height: 28),
                    ],
                  ),

                  // 3. User growth analytics by Month
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
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textSecondary),
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
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                  ),
                ] else if (selectedTab == 1) ...[
                  // 2. Activity Logs & Newly Registered Users Tab
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 4, child: _buildNewUsersList(context, dailyNewUsers)),
                        const SizedBox(width: 24),
                        Expanded(flex: 6, child: _buildAuditLogsList(activities)),
                      ],
                    )
                  else ...[
                    _buildNewUsersList(context, dailyNewUsers),
                    const SizedBox(height: 28),
                    _buildAuditLogsList(activities),
                  ],
                ] else if (selectedTab == 2) ...[
                  // 3. Pending Tasks (Support & Upgrade Verification Requests)
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildPendingUpgradesList(context, upgradeRequests)),
                        const SizedBox(width: 24),
                        Expanded(child: _buildPendingTicketsList(context, supportRequests)),
                      ],
                    )
                  else ...[
                    _buildPendingUpgradesList(context, upgradeRequests),
                    const SizedBox(height: 28),
                    _buildPendingTicketsList(context, supportRequests),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabButton(WidgetRef ref, int index, String label, IconData icon, int selectedTab) {
    final active = index == selectedTab;
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(adminDashboardTabProvider.notifier).state = index,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppColors.border : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: active ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  color: active ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
        gradient: LinearGradient(
          colors: [
            AppColors.card,
            color.withValues(alpha: 0.02),
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
                  color: color.withValues(alpha: 0.1),
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

  Widget _buildNewUsersList(BuildContext context, List dailyNewUsers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NEWLY REGISTERED USERS',
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textSecondary),
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
  }

  Widget _buildAuditLogsList(List activities) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'RECENT AUDIT LOGS',
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textSecondary),
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
  }

  Widget _buildPendingUpgradesList(BuildContext context, List upgradeRequests) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PENDING UPGRADE REQUESTS',
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 0.8),
          ),
          child: upgradeRequests.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(28.0),
                  child: Center(
                    child: Text('No pending upgrade requests.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: upgradeRequests.length,
                  separatorBuilder: (context, index) => const Divider(color: AppColors.border, height: 1),
                  itemBuilder: (context, idx) {
                    final req = upgradeRequests[idx] as Map<String, dynamic>;
                    final prof = req['profiles'] as Map? ?? {};
                    final name = prof['full_name'] as String? ?? 'User';
                    final plan = req['plan_type'] as String? ?? 'monthly';
                    final utr = req['utr'] as String? ?? '';
                    final dt = DateTime.parse(req['created_at'] as String);
                    final formattedTime = DateFormat('yyyy-MM-dd').format(dt.toLocal());

                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryNeon.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  plan.toUpperCase(),
                                  style: const TextStyle(fontSize: 10, color: AppColors.primaryNeon, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('UTR: $utr', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontFamily: 'monospace')),
                              Text(formattedTime, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
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
  }

  Widget _buildPendingTicketsList(BuildContext context, List supportRequests) {
    final pendingTickets = supportRequests.where((t) => t['status'] == 'pending' || t['status'] == 'open').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PENDING SUPPORT TICKETS',
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 0.8),
          ),
          child: pendingTickets.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(28.0),
                  child: Center(
                    child: Text('No active support tickets.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: pendingTickets.length,
                  separatorBuilder: (context, index) => const Divider(color: AppColors.border, height: 1),
                  itemBuilder: (context, idx) {
                    final ticket = pendingTickets[idx] as Map<String, dynamic>;
                    final prof = ticket['profiles'] as Map? ?? {};
                    final name = prof['full_name'] as String? ?? 'User';
                    final category = ticket['category'] as String? ?? 'support';
                    final description = ticket['description'] as String? ?? '';
                    final status = ticket['status'] as String? ?? 'open';
                    final dt = DateTime.parse(ticket['created_at'] as String);
                    final formattedTime = DateFormat('yyyy-MM-dd').format(dt.toLocal());

                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (status == 'open' ? Colors.orange : AppColors.error).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: status == 'open' ? Colors.orange : AppColors.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Cat: ${category.toUpperCase()}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                              Text(formattedTime, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
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
  }
}
