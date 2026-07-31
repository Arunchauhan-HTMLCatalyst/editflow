import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'notification_center_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../clients/providers/client_provider.dart';
import '../../projects/providers/project_provider.dart';
import '../../projects/models/project.dart';
import '../../settings/providers/settings_provider.dart';
import '../../settings/models/currency_config.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/providers/computed_providers.dart';
import '../../../shared/utils/premium_helper.dart';
import '../widgets/stat_card.dart';
import '../widgets/project_status_section.dart';
import '../widgets/top_clients_section.dart';
import '../widgets/top_freelancers_section.dart';
import '../widgets/goal_tracker.dart';
import '../../../shared/widgets/shimmer_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/ambient_glow_container.dart';
import '../../projects/repositories/comment_repository.dart';
import '../../../services/supabase_service.dart';

String _getTimeBasedGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) {
    return 'Good morning, EditFlow';
  } else if (hour < 17) {
    return 'Good afternoon, EditFlow';
  } else {
    return 'Good evening, EditFlow';
  }
}

class DashboardScreen extends ConsumerStatefulWidget {
  final String? inviteCode;

  const DashboardScreen({super.key, this.inviteCode});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late String _periodKey;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _periodKey = 'month_${now.year}_${now.month}';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(commentRepositoryProvider).cleanupOldVoiceNotes().catchError((e) {
        debugPrint('[DASHBOARD] Background voice note cleanup error: $e');
      });
      ref.read(authProvider.notifier).syncProfileData();
      
      final inviteCode = widget.inviteCode;
      if (inviteCode != null && inviteCode.isNotEmpty) {
        _autoLinkInviteCode(inviteCode);
      }
    });
  }

  Future<void> _autoLinkInviteCode(String inviteCode) async {
    debugPrint('[DASHBOARD] Auto-linking client workspace using invite code: $inviteCode');
    try {
      final messenger = ScaffoldMessenger.of(context);
      final uid = ref.read(authProvider).user?.id ?? SupabaseService.userId;
      final response = await SupabaseService.instance
          .from('clients')
          .update({
            'client_user_id': uid,
            'invite_code': null, // Clear invite code so it's one-time use!
          })
          .eq('invite_code', inviteCode)
          .select();

      if ((response as List).isNotEmpty) {
        ref.invalidate(clientProvider);
        ref.invalidate(projectProvider);
        messenger.showSnackBar(
          const SnackBar(content: Text('Connected to workspace successfully!')),
        );
      }
    } catch (e) {
      debugPrint('[DASHBOARD] Auto-linking failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(safeProjectsProvider);
    final clients = ref.watch(safeClientsProvider);
    final activities = ref.watch(recentActivityProvider).valueOrNull ?? [];
    final currency = ref.watch(currencyProvider);
    final settings = ref.watch(settingsProvider);
    final metrics = ref.watch(dashboardMetricsProvider);
    final periodMetrics = ref.watch(dashboardPeriodMetricsProvider(_periodKey));

    final projectsAsync = ref.watch(projectProvider);
    final clientsAsync = ref.watch(clientProvider);

    final isLoading = projectsAsync.isLoading || clientsAsync.isLoading;
    final hasError = projectsAsync.hasError || clientsAsync.hasError;
    final error = projectsAsync.error ?? clientsAsync.error;

    final isDashboardEmpty = projects.isEmpty && clients.isEmpty && !isLoading && !hasError;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    debugPrint('[DASHBOARD] BUILD projects=${projects.length} clients=${clients.length} activities=${activities.length} isLoading=$isLoading hasError=$hasError empty=$isDashboardEmpty');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientGlowContainer(
        child: SafeArea(
          top: true,
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () async {
              await ref.read(clientProvider.notifier).refresh();
              await ref.read(projectProvider.notifier).refresh();
            },
            child: isLoading
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      AppLayout.pagePadding(context),
                      AppLayout.pagePadding(context),
                      AppLayout.pagePadding(context),
                      AppLayout.pagePadding(context) + 24,
                    ),
                    children: [
                      // Greeting Banner Skeleton
                      const ShimmerCard(height: 104, borderRadius: 20),
                      const SizedBox(height: 24),
                      // Period filter row skeleton
                      Row(
                        children: [
                          const ShimmerCard(width: 180, height: 32, borderRadius: 16),
                          const Spacer(),
                          const ShimmerCard(width: 100, height: 20, borderRadius: 8),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Stat cards row 1
                      Row(
                        children: [
                          const Expanded(child: ShimmerCard(height: 110, borderRadius: 16)),
                          SizedBox(width: AppSpacing.sm),
                          const Expanded(child: ShimmerCard(height: 110, borderRadius: 16)),
                        ],
                      ),
                      SizedBox(height: AppSpacing.sm),
                      // Stat cards row 2
                      Row(
                        children: [
                          const Expanded(child: ShimmerCard(height: 110, borderRadius: 16)),
                          SizedBox(width: AppSpacing.sm),
                          const Expanded(child: ShimmerCard(height: 110, borderRadius: 16)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Section header 2
                      const ShimmerCard(width: 140, height: 18, borderRadius: 8),
                      const SizedBox(height: 12),
                      // Project card skeletons
                      const ShimmerCard(height: 90, borderRadius: 16),
                      const SizedBox(height: 10),
                      const ShimmerCard(height: 90, borderRadius: 16),
                      const SizedBox(height: 10),
                      const ShimmerCard(height: 90, borderRadius: 16),
                    ],
                  )
                : (isDashboardEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          AppLayout.pagePadding(context),
                          AppLayout.pagePadding(context),
                          AppLayout.pagePadding(context),
                          AppLayout.pagePadding(context) + 24,
                        ),
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Dashboard',
                                    style: AppTextStyles.title1(isDark).copyWith(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _getTimeBasedGreeting(),
                                    style: AppTextStyles.caption(isDark).copyWith(
                                      fontSize: 14,
                                      color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                              if (!AppLayout.isTablet(context))
                                Row(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Consumer(
                                        builder: (context, ref, child) {
                                          final activitiesAsync = ref.watch(recentActivityProvider);
                                          final count = activitiesAsync.valueOrNull?.length ?? 0;
                                          final iconButton = IconButton(
                                            icon: Icon(
                                              Icons.notifications_none_rounded,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                              size: 20,
                                            ),
                                            onPressed: () => context.push('/notifications'),
                                          );
                                          if (count > 0) {
                                            return Badge(
                                              label: Text('$count', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                                              backgroundColor: AppColors.error,
                                              child: iconButton,
                                            );
                                          }
                                          return iconButton;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: IconButton(
                                        icon: Icon(
                                          Icons.settings_outlined,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          size: 20,
                                        ),
                                        onPressed: () => context.push('/settings'),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.6,
                            child: EmptyStateWidget(
                              icon: Icons.dashboard_customize_outlined,
                              title: settings.isClientMode 
                                  ? 'No Projects Assigned' 
                                  : (clients.isEmpty ? 'No Clients Yet' : 'Welcome to EditFlow'),
                              subtitle: settings.isClientMode
                                  ? 'You can assign a project to any freelancer you work with.'
                                  : (clients.isEmpty 
                                      ? 'Add a client first to start tracking your projects and metrics.' 
                                      : 'Add clients and projects to start tracking your freelance metrics.'),
                              actionLabel: settings.isClientMode 
                                  ? 'Assign Project' 
                                  : (clients.isEmpty ? 'Add Client' : 'Add Project'),
                              onAction: () {
                                if (!settings.isClientMode && clients.isEmpty) {
                                  if (PremiumHelper.checkClientLimit(ref, context)) {
                                    context.push('/add-client');
                                  }
                                } else {
                                  if (PremiumHelper.checkProjectLimit(ref, context)) {
                                    context.push('/projects/add');
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      )
                    : _DashboardLayout(
                        metrics: metrics,
                        periodMetrics: periodMetrics,
                        projects: projects,
                        currency: currency,
                        settings: settings,
                        isLoading: isLoading,
                        hasError: hasError,
                        error: error,
                        onRetry: () {
                          ref.read(clientProvider.notifier).refresh();
                          ref.read(projectProvider.notifier).refresh();
                        },
                        onPeriodChanged: (p) => setState(() => _periodKey = p),
                        periodKey: _periodKey,
                        getMonthYearItems: _getMonthYearDropdownItems,
                      )),
          ),
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _getMonthYearDropdownItems(bool isDark) {
    final List<DropdownMenuItem<String>> items = [];
    final now = DateTime.now();
    
    for (int i = 0; i < 12; i++) {
      final date = DateTime(now.year, now.month - i, 1);
      final key = 'month_${date.year}_${date.month}';
      
      String label = DateFormat('MMMM yyyy').format(date);
      if (i == 0) {
        label += ' (Current)';
      }
      
      items.add(DropdownMenuItem<String>(
        value: key,
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
      ));
    }
    
    for (int i = 0; i < 4; i++) {
      final year = now.year - i;
      final key = 'year_$year';
      
      String label = '$year';
      if (i == 0) {
        label += ' (Current)';
      }
      
      items.add(DropdownMenuItem<String>(
        value: key,
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
      ));
    }
    
    return items;
  }
}

class _DashboardLayout extends ConsumerWidget {
  final DashboardMetrics metrics;
  final List<PeriodMetricItem> periodMetrics;
  final List<Project> projects;
  final CurrencyConfig currency;
  final SettingsState settings;
  final bool isLoading;
  final bool hasError;
  final Object? error;
  final VoidCallback onRetry;
  final ValueChanged<String> onPeriodChanged;
  final String periodKey;
  final List<DropdownMenuItem<String>> Function(bool) getMonthYearItems;

  const _DashboardLayout({
    required this.metrics,
    required this.periodMetrics,
    required this.projects,
    required this.currency,
    required this.settings,
    required this.isLoading,
    required this.hasError,
    this.error,
    required this.onRetry,
    required this.onPeriodChanged,
    required this.periodKey,
    required this.getMonthYearItems,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget buildGreetingBanner() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 20.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF171D1F), const Color(0xFF101517)]
                : [AppColors.primary, AppColors.primary.withValues(alpha: 0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: isDark ? AppColors.border : AppColors.primary.withValues(alpha: 0.15),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? AppColors.primary.withValues(alpha: 0.04)
                  : AppColors.primary.withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        settings.isClientMode ? 'CLIENT PORTAL' : 'WORKSPACE',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: isDark ? AppColors.primaryNeon : Colors.white.withValues(alpha: 0.9),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          settings.isClientMode ? 'CLIENT' : 'FREELANCER',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: isDark ? AppColors.primaryNeon : Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _getTimeBasedGreeting(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Welcome to your EditFlow workspace.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            if (!AppLayout.isTablet(context))
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 0.8,
                      ),
                    ),
                    child: Builder(
                      builder: (context) {
                        final activitiesAsync = ref.watch(recentActivityProvider);
                        final count = activitiesAsync.valueOrNull?.length ?? 0;
                        
                        final iconButton = IconButton(
                          icon: const Icon(
                            Icons.notifications_none_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () {
                            final isDesktop = MediaQuery.of(context).size.width > 800;
                            if (isDesktop) {
                              showDialog(
                                context: context,
                                barrierColor: Colors.black26,
                                builder: (context) {
                                  return Center(
                                    child: Container(
                                      width: 420,
                                      height: 600,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.2),
                                            blurRadius: 12,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: const NotificationCenterScreen(isDialog: true),
                                      ),
                                    ),
                                  );
                                },
                              );
                            } else {
                              context.push('/notifications');
                            }
                          },
                        );

                        if (count > 0) {
                          return Badge(
                            label: Text('$count', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                            backgroundColor: AppColors.error,
                            child: iconButton,
                          );
                        }
                        return iconButton;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 0.8,
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.settings_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => context.push('/settings'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      );
    }

    Widget buildOverviewList() {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppLayout.pagePadding(context),
          AppLayout.pagePadding(context),
          AppLayout.pagePadding(context),
          AppLayout.pagePadding(context) + 24,
        ),
        children: [
          if (hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _ErrorBanner(onRetry: onRetry, error: error),
            ),
          
          _StaggeredSection(
            index: 0,
            child: buildGreetingBanner(),
          ),
          const SizedBox(height: 24),

          _StaggeredSection(
            index: 1,
            child: Row(
              children: [
                Expanded(
                  flex: 7,
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surface : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 13,
                          color: isDark ? AppColors.primaryNeon : AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 1,
                          height: 14,
                          color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: periodKey != 'all' ? periodKey : null,
                              isExpanded: true,
                              icon: Icon(
                                Icons.keyboard_arrow_down_rounded, 
                                size: 16,
                                color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                              ),
                              hint: Text(
                                'Select Month / Year',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                                ),
                              ),
                              dropdownColor: isDark ? AppColors.surface : Colors.white,
                              items: getMonthYearItems(isDark),
                              onChanged: (val) {
                                if (val != null) {
                                  onPeriodChanged(val);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surface : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.all_inclusive_rounded,
                          size: 13,
                          color: isDark ? AppColors.primary : AppColors.primaryNeon,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 1,
                          height: 14,
                          color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: periodKey == 'all' ? 'all' : null,
                              isExpanded: true,
                              icon: Icon(
                                Icons.keyboard_arrow_down_rounded, 
                                size: 16,
                                color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                              ),
                              hint: Text(
                                'Period',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                                ),
                              ),
                              dropdownColor: isDark ? AppColors.surface : Colors.white,
                              items: [
                                DropdownMenuItem<String>(
                                  value: 'all',
                                  child: Text('All Time', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                                ),
                              ],
                              onChanged: (val) {
                                if (val == 'all') {
                                  onPeriodChanged('all');
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _StaggeredSection(
            index: 2,
            child: _MetricRow(metrics: periodMetrics),
          ),
          const SizedBox(height: 16),
          _StaggeredSection(
            index: 3,
            child: Builder(
              builder: (context) {
                final now = DateTime.now();
                int goalYear = now.year;
                int goalMonth = now.month;
                
                if (periodKey.startsWith('month_')) {
                  final parts = periodKey.split('_');
                  goalYear = int.parse(parts[1]);
                  goalMonth = int.parse(parts[2]);
                }
                
                final start = DateTime(goalYear, goalMonth, 1);
                final end = goalMonth == 12 ? DateTime(goalYear + 1, 1, 1) : DateTime(goalYear, goalMonth + 1, 1);
                final thisMonthProjects = projects.where((p) => p.createdAt.isAfter(start) && p.createdAt.isBefore(end));
                final thisMonthEarning = thisMonthProjects.fold<double>(0.0, (s, p) => s + p.price);
                
                return GoalTracker(
                  currentRevenue: thisMonthEarning,
                  goal: settings.monthlyGoal,
                  formatValue: currency.format,
                  label: settings.isClientMode ? 'MONTHLY BUDGET' : 'MONTHLY GOAL',
                  isExpense: settings.isClientMode,
                );
              }
            ),
          ),
          const SizedBox(height: 16),
          _StaggeredSection(
            index: 4,
            child: _buildCompactRow(context, [
              if (settings.isClientMode)
                TopFreelancersSection(freelancers: metrics.topFreelancers)
              else
                TopClientsSection(
                  clients: metrics.topClients
                      .map((e) => TopClientData(client: e.client, revenue: e.revenue, percentage: e.percentage))
                      .toList(),
                  formatValue: currency.format,
                ),
              ProjectStatusSection(statusData: metrics.pipelineMap, total: projects.length),
            ]),
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    final isDesktop = MediaQuery.of(context).size.width > 960;
    if (isDesktop) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: buildOverviewList(),
        ),
      );
    }

    return buildOverviewList();
  }

  Widget _buildCompactRow(BuildContext context, List<Widget> items) {
    final isMobile = !AppLayout.isTablet(context);
    if (isMobile) {
      return Column(
        children: items
            .map((w) => Padding(padding: const EdgeInsets.only(bottom: 16.0), child: w))
            .toList(),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map((w) => Expanded(
                  child: Padding(
                padding: EdgeInsets.only(right: items.last == w ? 0 : 16.0),
                child: w,
              )))
          .toList(),
    );
  }

}

class _StaggeredSection extends StatefulWidget {
  final Widget child;
  final int index;

  const _StaggeredSection({required this.child, required this.index});

  @override
  State<_StaggeredSection> createState() => _StaggeredSectionState();
}

class _StaggeredSectionState extends State<_StaggeredSection> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    Future.delayed(Duration(milliseconds: widget.index * 80), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}



class _ErrorBanner extends StatelessWidget {
  final VoidCallback onRetry;
  final Object? error;
  const _ErrorBanner({required this.onRetry, this.error});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.15), width: 0.5),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 14, color: AppColors.error),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: GestureDetector(
              onTap: error == null
                  ? null
                  : () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Error Details'),
                          content: SingleChildScrollView(
                            child: Text(
                              error.toString(),
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
              child: Text(
                error != null ? 'Could not refresh (Tap for details)' : 'Could not refresh',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.error,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: onRetry,
            child: const Text('Retry', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final List<PeriodMetricItem> metrics;
  const _MetricRow({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final isMobile = !AppLayout.isTablet(context);
    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: metrics[0].label,
                  value: metrics[0].value,
                  icon: metrics[0].icon,
                  iconColor: metrics[0].iconColor,
                  progressRatio: metrics[0].progressRatio,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: StatCard(
                  label: metrics[1].label,
                  value: metrics[1].value,
                  icon: metrics[1].icon,
                  iconColor: metrics[1].iconColor,
                  progressRatio: metrics[1].progressRatio,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: metrics[2].label,
                  value: metrics[2].value,
                  icon: metrics[2].icon,
                  iconColor: metrics[2].iconColor,
                  progressRatio: metrics[2].progressRatio,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: StatCard(
                  label: metrics[3].label,
                  value: metrics[3].value,
                  icon: metrics[3].icon,
                  iconColor: metrics[3].iconColor,
                  progressRatio: metrics[3].progressRatio,
                ),
              ),
            ],
          ),
        ],
      );
    }
    return Row(
      children: metrics
          .map((m) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: m == metrics.last ? 0 : AppSpacing.sm),
                  child: StatCard(
                    label: m.label,
                    value: m.value,
                    icon: m.icon,
                    iconColor: m.iconColor,
                    progressRatio: m.progressRatio,
                  ),
                ),
              ))
          .toList(),
    );
  }
}

