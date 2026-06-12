import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
import '../../../shared/models/activity.dart';
import '../../../shared/providers/computed_providers.dart';
import '../widgets/stat_card.dart';
import '../widgets/project_status_section.dart';
import '../widgets/top_clients_section.dart';
import '../widgets/top_freelancers_section.dart';
import '../widgets/goal_tracker.dart';
import '../widgets/recent_activity.dart';
import '../../../shared/widgets/shimmer_card.dart';
import '../../../shared/widgets/empty_state.dart';

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
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DashboardPeriod _period = DashboardPeriod.month;

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(safeProjectsProvider);
    final clients = ref.watch(safeClientsProvider);
    final activities = ref.watch(recentActivityProvider).valueOrNull ?? [];
    final currency = ref.watch(currencyProvider);
    final settings = ref.watch(settingsProvider);
    final metrics = ref.watch(dashboardMetricsProvider);
    final periodMetrics = ref.watch(dashboardPeriodMetricsProvider(_period));

    final projectsAsync = ref.watch(projectProvider);
    final clientsAsync = ref.watch(clientProvider);

    final isLoading = projectsAsync.isLoading || clientsAsync.isLoading;
    final hasError = projectsAsync.hasError || clientsAsync.hasError;
    final error = projectsAsync.error ?? clientsAsync.error;

    final isDashboardEmpty = projects.isEmpty && clients.isEmpty && !isLoading && !hasError;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    debugPrint('[DASHBOARD] BUILD projects=${projects.length} clients=${clients.length} activities=${activities.length} isLoading=$isLoading hasError=$hasError empty=$isDashboardEmpty');

    return Scaffold(
      body: SafeArea(
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerCard(width: 140, height: 28, borderRadius: 8),
                            SizedBox(height: 8),
                            ShimmerCard(width: 200, height: 14, borderRadius: 4),
                          ],
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surface : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const ShimmerCard(width: 180, height: 36, borderRadius: 12),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: ShimmerCard(height: 100, borderRadius: 16)),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(child: ShimmerCard(height: 100, borderRadius: 16)),
                      ],
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(child: ShimmerCard(height: 100, borderRadius: 16)),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(child: ShimmerCard(height: 100, borderRadius: 16)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const ShimmerCard(height: 120, borderRadius: 16),
                    const SizedBox(height: 16),
                    const ShimmerCard(height: 180, borderRadius: 16),
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
                            IconButton(
                              icon: Icon(
                                Icons.settings_outlined,
                                color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                              ),
                              onPressed: () => context.push('/settings'),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: EmptyStateWidget(
                            icon: Icons.dashboard_customize_outlined,
                            title: settings.isClientMode ? 'No Projects Yet' : 'Welcome to EditFlow',
                            subtitle: settings.isClientMode
                                ? 'No video projects have been assigned to you yet.'
                                : 'Add clients and projects to start tracking your freelance metrics.',
                            actionLabel: settings.isClientMode ? null : 'Add Project',
                            onAction: settings.isClientMode ? null : () => context.push('/projects/add'),
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
                      activities: activities,
                      isLoading: isLoading,
                      hasError: hasError,
                      error: error,
                      onRetry: () {
                        ref.read(clientProvider.notifier).refresh();
                        ref.read(projectProvider.notifier).refresh();
                      },
                      onPeriodChanged: (p) => setState(() => _period = p),
                      currentPeriod: _period,
                    )),
        ),
      ),
    );
  }
}

class _DashboardLayout extends StatelessWidget {
  final DashboardMetrics metrics;
  final List<PeriodMetricItem> periodMetrics;
  final List<Project> projects;
  final CurrencyConfig currency;
  final SettingsState settings;
  final List<Activity> activities;
  final bool isLoading;
  final bool hasError;
  final Object? error;
  final VoidCallback onRetry;
  final ValueChanged<DashboardPeriod> onPeriodChanged;
  final DashboardPeriod currentPeriod;

  const _DashboardLayout({
    required this.metrics,
    required this.periodMetrics,
    required this.projects,
    required this.currency,
    required this.settings,
    required this.activities,
    required this.isLoading,
    required this.hasError,
    this.error,
    required this.onRetry,
    required this.onPeriodChanged,
    required this.currentPeriod,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          child: Row(
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
              IconButton(
                icon: Icon(
                  Icons.settings_outlined,
                  color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                ),
                onPressed: () => context.push('/settings'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        _StaggeredSection(
          index: 1,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _PeriodFilter(
                current: currentPeriod,
                onChanged: onPeriodChanged,
                isDark: isDark,
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
        if (!settings.isClientMode) ...[
          _StaggeredSection(
            index: 3,
            child: GoalTracker(
              currentRevenue: metrics.totalReceived,
              goal: settings.monthlyGoal,
              formatValue: currency.format,
            ),
          ),
          const SizedBox(height: 16),
        ],
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
        if (!settings.isClientMode && activities.isNotEmpty) ...[
          const SizedBox(height: 16),
          _StaggeredSection(
            index: 5,
            child: RecentActivityWidget(activities: activities),
          ),
        ],
      ],
    );
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

class _PeriodFilter extends StatelessWidget {
  final DashboardPeriod current;
  final ValueChanged<DashboardPeriod> onChanged;
  final bool isDark;

  const _PeriodFilter({required this.current, required this.onChanged, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PeriodTab(label: 'Month', selected: current == DashboardPeriod.month, onTap: () => onChanged(DashboardPeriod.month), isDark: isDark),
          _PeriodTab(label: 'Year', selected: current == DashboardPeriod.year, onTap: () => onChanged(DashboardPeriod.year), isDark: isDark),
          _PeriodTab(label: 'All time', selected: current == DashboardPeriod.all, onTap: () => onChanged(DashboardPeriod.all), isDark: isDark),
        ],
      ),
    );
  }
}

class _PeriodTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;

  const _PeriodTab({required this.label, required this.selected, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? AppColors.card : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected
                ? AppColors.primary
                : (isDark ? AppColors.textSecondary : const Color(0xFF64748B)),
          ),
        ),
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
              Expanded(child: StatCard(label: metrics[0].label, value: metrics[0].value, icon: metrics[0].icon, iconColor: metrics[0].iconColor)),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: StatCard(label: metrics[1].label, value: metrics[1].value, icon: metrics[1].icon, iconColor: metrics[1].iconColor)),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: StatCard(label: metrics[2].label, value: metrics[2].value, icon: metrics[2].icon, iconColor: metrics[2].iconColor)),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: StatCard(label: metrics[3].label, value: metrics[3].value, icon: metrics[3].icon, iconColor: metrics[3].iconColor)),
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
                  child: StatCard(label: m.label, value: m.value, icon: m.icon, iconColor: m.iconColor),
                ),
              ))
          .toList(),
    );
  }
}

