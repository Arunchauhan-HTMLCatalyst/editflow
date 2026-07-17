import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_layout.dart';
import '../../../shared/constants/status_colors.dart';
import '../../../shared/providers/computed_providers.dart';
import '../../../shared/widgets/ambient_glow_container.dart';
import '../../../shared/widgets/animated_list_item.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../projects/models/project.dart';
import '../../settings/models/currency_config.dart';
import '../../settings/providers/settings_provider.dart';
import '../../../services/supabase_service.dart';
import '../providers/client_provider.dart';
import '../../projects/providers/project_provider.dart';
import '../../auth/providers/auth_provider.dart';

class FreelancerDetailScreen extends ConsumerWidget {
  final String freelancerId;

  const FreelancerDetailScreen({
    super.key,
    required this.freelancerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final padding = AppLayout.pagePadding(context);
    final currency = ref.watch(currencyProvider);
    final projects = ref.watch(freelancerProjectsProvider(freelancerId));

    // Get freelancer details from first project
    String name = 'Freelancer';
    for (final p in projects) {
      if (p.freelancerName != null && p.freelancerName!.isNotEmpty) {
        name = p.freelancerName!;
        break;
      }
    }

    final initials = name.isNotEmpty
        ? name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : '?';

    // Metrics for this freelancer
    final totalPaid = projects.fold<double>(0.0, (s, p) => s + p.receivedAmount);
    final totalRemaining = projects.fold<double>(0.0, (s, p) => s + p.remainingAmount);
    final totalValue = totalPaid + totalRemaining;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                CupertinoIcons.back,
                size: 18,
                color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
              ),
            ),
            onPressed: () => context.pop(),
          ),
        ),
        title: Text(
          'Freelancer Profile',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
          ),
        ),
        actions: [
          CupertinoButton(
            padding: const EdgeInsets.only(right: 12.0),
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
              child: const Icon(
                CupertinoIcons.clear_circled,
                size: 18,
                color: AppColors.error,
              ),
            ),
            onPressed: () => _disconnectFreelancer(context, ref),
          ),
        ],
      ),
      body: AmbientGlowContainer(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 800;

              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left Column: Profile card & Revenue metrics
                    Expanded(
                      flex: 4,
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(padding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildProfileCard(isDark, name, initials),
                            const SizedBox(height: 14),
                            _buildMetricsBar(isDark, totalValue, totalPaid, totalRemaining, projects, currency),
                          ],
                        ),
                      ),
                    ),
                    // Divider
                    Container(
                      width: 1,
                      color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                    ),
                    // Right Column: Projects list
                    Expanded(
                      flex: 6,
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(padding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildProjectsSectionHeader(context, isDark, name, freelancerId),
                            const SizedBox(height: 12),
                            _buildProjectsList(context, projects, currency),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }

              // Mobile layout
              return ListView(
                padding: EdgeInsets.all(padding),
                children: [
                  _buildProfileCard(isDark, name, initials),
                  const SizedBox(height: 14),
                  _buildMetricsBar(isDark, totalValue, totalPaid, totalRemaining, projects, currency),
                  const SizedBox(height: 20),
                  _buildProjectsSectionHeader(context, isDark, name, freelancerId),
                  const SizedBox(height: 12),
                  _buildProjectsList(context, projects, currency),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(bool isDark, String name, String initials) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF171D1F), const Color(0xFF101517)]
              : [AppColors.primary, AppColors.primary.withValues(alpha: 0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isDark ? AppColors.border : AppColors.primary.withValues(alpha: 0.15),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? AppColors.primary.withValues(alpha: 0.04)
                : AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF273135), const Color(0xFF1F2629)]
                    : [Colors.white.withValues(alpha: 0.25), Colors.white.withValues(alpha: 0.12)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(
                color: isDark ? AppColors.border : Colors.white.withValues(alpha: 0.35),
                width: 1.0,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.primaryNeon.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'PARTNER CREATIVE',
                        style: TextStyle(
                          fontSize: 7.0,
                          fontWeight: FontWeight.w900,
                          color: isDark ? AppColors.primaryNeon : Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Active Collaborator',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsBar(
    bool isDark,
    double totalValue,
    double totalPaid,
    double totalRemaining,
    List<Project> projects,
    CurrencyConfig currency,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14191B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _metricColumn('TOTAL', currency.format(totalValue), AppColors.primary, isDark),
          _divider(isDark),
          _metricColumn('PAID', currency.format(totalPaid), AppColors.success, isDark),
          _divider(isDark),
          _metricColumn('PENDING', currency.format(totalRemaining), AppColors.warning, isDark),
          _divider(isDark),
          _metricColumn('ACTIVE', '${projects.length}', AppColors.info, isDark),
        ],
      ),
    );
  }

  Widget _buildProjectsSectionHeader(
    BuildContext context,
    bool isDark,
    String name,
    String freelancerId,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'PROJECTS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.primary.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(CupertinoIcons.plus, size: 12, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  'Assign Project',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          onPressed: () {
            context.push('/projects/add?freelancerId=$freelancerId&freelancerName=${Uri.encodeComponent(name)}');
          },
        ),
      ],
    );
  }

  Widget _buildProjectsList(BuildContext context, List<Project> projects, CurrencyConfig currency) {
    if (projects.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40.0),
        child: EmptyStateWidget(
          icon: Icons.assignment_outlined,
          title: 'No Projects Found',
          subtitle: 'There are no projects assigned under this freelancer.',
        ),
      );
    }
    return Column(
      children: List.generate(projects.length, (index) {
        final project = projects[index];
        return AnimatedListItem(
          key: ValueKey(project.id),
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: _FreelancerProjectCard(
              key: ValueKey(project.id),
              project: project,
              currency: currency,
              onTap: () => context.push('/projects/${project.id}'),
            ),
          ),
        );
      }),
    );
  }

  static Widget _metricColumn(String label, String value, Color color, bool isDark) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  static Widget _divider(bool isDark) {
    return Container(
      height: 20,
      width: 0.5,
      color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
    );
  }

  Future<void> _disconnectFreelancer(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Freelancer'),
        content: const Text(
          'Are you sure you want to disconnect from this freelancer? '
          'You will lose access to all shared projects and reviews.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            child: const Text('Disconnect', style: TextStyle(color: AppColors.error)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        final clientName = ref.read(authProvider).user?.userMetadata?['full_name'] ?? 'Client';

        final response = await SupabaseService.instance
            .from('clients')
            .update({'client_user_id': null})
            .eq('user_id', freelancerId)
            .eq('client_user_id', SupabaseService.userId)
            .select();

        if ((response as List).isEmpty) {
          throw Exception('Failed to disconnect. (No matching connection found in database. freelancerId: $freelancerId, myId: ${SupabaseService.userId})');
        }

        unawaited(() async {
          try {
            await SupabaseService.instance.functions.invoke(
              'send-push',
              body: {
                'recipientUserId': freelancerId,
                'title': 'Workspace Disconnected',
                'body': 'Client "$clientName" has disconnected from your workspace.',
                'route': '/clients',
              },
            );
          } catch (err) {
            debugPrint('[DISCONNECT NOTIFICATION ERROR] $err');
          }
        }());

        ref.invalidate(clientProvider);
        ref.invalidate(projectProvider);
        
        if (context.mounted) {
          context.pop();
        }
        messenger.showSnackBar(
          const SnackBar(content: Text('Disconnected from freelancer successfully.')),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Disconnection failed: $e')),
        );
      }
    }
  }
}

class _FreelancerProjectCard extends StatefulWidget {
  final Project project;
  final CurrencyConfig currency;
  final VoidCallback onTap;

  const _FreelancerProjectCard({
    super.key,
    required this.project,
    required this.currency,
    required this.onTap,
  });

  @override
  State<_FreelancerProjectCard> createState() => _FreelancerProjectCardState();
}

class _FreelancerProjectCardState extends State<_FreelancerProjectCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = widget.project;
    final c = widget.currency;
    final statusCol = statusColor(p.status);
    final ratio = p.price > 0 ? p.receivedAmount / p.price : 0.0;
    final percent = (ratio * 100).toStringAsFixed(0);

    final timeStr = p.deadline != null
        ? DateFormat('MMM d, yyyy').format(p.deadline!.toLocal())
        : 'No deadline';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: _isHovered ? Matrix4.translationValues(0, -3, 0) : Matrix4.identity(),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF14191B) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: _isHovered
                ? AppColors.primary.withValues(alpha: 0.4)
                : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0)),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.06)
                  : Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
              blurRadius: _isHovered ? 12 : 6,
              offset: Offset(0, _isHovered ? 4 : 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8.5,
                        height: 8.5,
                        decoration: BoxDecoration(
                          color: statusCol,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          p.name,
                          style: TextStyle(
                            fontSize: 15.2,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        c.format(p.price),
                        style: const TextStyle(
                          fontSize: 15.2,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.calendar,
                        size: 13,
                        color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 12.0,
                          color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '•',
                        style: TextStyle(
                          fontSize: 8,
                          color: isDark ? AppColors.textMuted : const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        p.status.displayName.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: statusCol,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$percent% Paid',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: ratio >= 1.0
                              ? Colors.green
                              : (isDark ? AppColors.textSecondary : const Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
