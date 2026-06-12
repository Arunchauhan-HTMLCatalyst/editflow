import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_layout.dart';
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
import '../widgets/goal_tracker.dart';
import '../widgets/recent_activity.dart';

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

    final isDashboardEmpty = projects.isEmpty && clients.isEmpty && !isLoading && !hasError;

    print('[DASHBOARD] BUILD projects=${projects.length} clients=${clients.length} activities=${activities.length} isLoading=$isLoading hasError=$hasError empty=$isDashboardEmpty');

    return Scaffold(
      body: SafeArea(
        top: true,
        bottom: false,
        child: RefreshIndicator(
        onRefresh: () async {
          await ref.read(clientProvider.notifier).refresh();
          await ref.read(projectProvider.notifier).refresh();
        },
        child: isDashboardEmpty
            ? ListView(
                physics: AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: Center(
                      child: isLoading
                          ? CircularProgressIndicator()
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.dashboard_outlined, size: 40, color: AppColors.textMuted),
                                SizedBox(height: AppSpacing.sm),
                                Text('No data yet', style: AppTextStyles.caption(true)),
                              ],
                            ),
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
                onRetry: () {
                  ref.read(clientProvider.notifier).refresh();
                  ref.read(projectProvider.notifier).refresh();
                },
                onPeriodChanged: (p) => setState(() => _period = p),
                currentPeriod: _period,
              ),
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
    required this.onRetry,
    required this.onPeriodChanged,
    required this.currentPeriod,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppLayout.pagePadding(context),
        AppLayout.pagePadding(context),
        AppLayout.pagePadding(context),
        AppLayout.pagePadding(context) + 24,
      ),
      children: [
        if (isLoading)
          Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5)),
                SizedBox(width: AppSpacing.sm),
                Text('Refreshing...', style: AppTextStyles.small(true)),
              ],
            ),
          ),
        if (hasError)
          Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: _ErrorBanner(onRetry: onRetry),
          ),
        _PeriodFilter(current: currentPeriod, onChanged: onPeriodChanged, isDark: Theme.of(context).brightness == Brightness.dark),
        SizedBox(height: AppSpacing.xs),
        _MetricRow(metrics: periodMetrics),
        SizedBox(height: AppSpacing.sm),
        GoalTracker(
          currentRevenue: metrics.totalReceived,
          goal: settings.monthlyGoal,
          formatValue: currency.format,
        ),
        SizedBox(height: AppSpacing.sm),
        _buildCompactRow(context, [
          TopClientsSection(
            clients: metrics.topClients
                .map((e) => TopClientData(client: e.client, revenue: e.revenue, percentage: e.percentage))
                .toList(),
            formatValue: currency.format,
          ),
          ProjectStatusSection(statusData: metrics.pipelineMap, total: projects.length),
        ]),
        if (activities.isNotEmpty) ...[
          SizedBox(height: AppSpacing.sm),
          RecentActivityWidget(activities: activities),
        ],
      ],
    );
  }

  Widget _buildCompactRow(BuildContext context, List<Widget> items) {
    final isMobile = !AppLayout.isTablet(context);
    if (isMobile) {
      return Column(
        children: items
            .map((w) => Padding(padding: EdgeInsets.only(bottom: AppSpacing.xs), child: w))
            .toList(),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map((w) => Expanded(child: Padding(padding: EdgeInsets.only(right: items.last == w ? 0 : AppSpacing.sm), child: w)))
          .toList(),
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
    return Row(
      children: [
        _PeriodTab(label: 'Month', selected: current == DashboardPeriod.month, onTap: () => onChanged(DashboardPeriod.month), isDark: isDark),
        SizedBox(width: 2),
        _PeriodTab(label: 'Year', selected: current == DashboardPeriod.year, onTap: () => onChanged(DashboardPeriod.year), isDark: isDark),
        SizedBox(width: 2),
        _PeriodTab(label: 'All', selected: current == DashboardPeriod.all, onTap: () => onChanged(DashboardPeriod.all), isDark: isDark),
      ],
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
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.primary : (isDark ? AppColors.textMuted : const Color(0xFF71717A)),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
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
            child: Text('Could not refresh', style: TextStyle(fontSize: 13, color: AppColors.error)),
          ),
          GestureDetector(
            onTap: onRetry,
            child: Text('Retry', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.error)),
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
