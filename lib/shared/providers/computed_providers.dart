import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/clients/models/client.dart';
import '../../features/clients/providers/client_provider.dart';
import '../../features/projects/models/project.dart';
import '../../features/projects/models/project_status.dart';
import '../../features/projects/providers/project_provider.dart';
import '../../features/settings/providers/settings_provider.dart';
import '../../services/supabase_service.dart';
import '../../services/local_notification_service.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../models/activity.dart';
import '../../core/theme/app_colors.dart';

// ─── Safe Data Wrappers ──────────────────────────────────────────────
// Mirror the async provider state as a synchronous List, returning
// the cached/historical data during loading/error transitions.
// The underlying providers (ProjectProvider / ClientProvider) maintain
// their own internal _lastValidData caches that survive rebuilds.

final safeProjectsProvider = Provider<List<Project>>((ref) {
  final async = ref.watch(projectProvider);
  final result = async.valueOrNull ?? [];
  debugPrint('[SAFE PROJECTS] hasValue=${async.hasValue} isLoading=${async.isLoading} returning=${result.length}');
  return result;
});

final safeClientsProvider = Provider<List<Client>>((ref) {
  final async = ref.watch(clientProvider);
  final result = async.valueOrNull ?? [];
  debugPrint('[SAFE CLIENTS] hasValue=${async.hasValue} isLoading=${async.isLoading} returning=${result.length}');
  return result;
});

// ─── Activity Provider (with realtime) ────────────────────────────────

final recentActivityProvider = AsyncNotifierProvider<RecentActivityNotifier, List<Activity>>(
  () => RecentActivityNotifier(),
);

class RecentActivityNotifier extends AsyncNotifier<List<Activity>> {
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  List<Activity> _lastActivities = [];
  final Set<String> _seenActivityIds = {};
  bool _isFirstLoad = true;

  void _triggerLocalNotification(Activity activity) {
    // Skip client logs and freelancer self project creations from triggering local notification banners
    if (activity.type == 'client_created' || activity.type == 'client_deleted') {
      return;
    }
    if (activity.type == 'project_created' && activity.description.startsWith('Created project')) {
      return;
    }

    String title = 'EditFlow Update';
    switch (activity.type) {
      case 'comment_created':
        title = '💬 New Feedback Comment';
        break;
      case 'project_created':
        title = '📁 Project Created';
        break;
      case 'payment_overdue':
        title = '⚠️ Payment Overdue';
        break;
      case 'due_date_overdue':
        title = '🚨 Deadline Passed';
        break;
      case 'due_date_12h':
        title = '⏰ Deadline Warning (12h)';
        break;
      case 'due_date_1d':
        title = '⏰ Deadline Warning (24h)';
        break;
      case 'due_date_2d':
        title = '⏰ Deadline Warning (48h)';
        break;
      case 'project_updated':
        title = '✏️ Project Updated';
        break;
      case 'status_changed':
        title = '🔄 Status Changed';
        break;
      case 'payment_received':
        title = '💰 Payment Received';
        break;
      case 'client_created':
        title = '👥 Client Connected';
        break;
    }

    final notificationId = activity.id.hashCode;
    LocalNotificationService.showNotification(
      id: notificationId,
      title: title,
      body: activity.description,
      payload: activity.referenceId,
    );
  }

  @override
  Future<List<Activity>> build() async {
    final authState = ref.watch(authProvider);
    if (authState.status != AuthStatus.authenticated) {
      debugPrint('[ACTIVITY BUILD] not authenticated - clearing cache');
      _lastActivities = [];
      _seenActivityIds.clear();
      _isFirstLoad = true;
      return [];
    }

    final uid = authState.user?.id ?? SupabaseService.userId;
    debugPrint('[ACTIVITY BUILD] uid=$uid cacheLen=${_lastActivities.length}');
    _subscription?.cancel();
    _subscription = SupabaseService.instance
        .from('activities')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .listen(
      (rows) {
        try {
          final activities = rows
              .map((e) => Activity.fromJson(e))
              .where((act) => act.type != 'support_ticket')
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          debugPrint('[ACTIVITY STREAM] received ${activities.length}');

          // Check for new activities to show notifications
          if (_isFirstLoad) {
            for (final act in activities) {
              _seenActivityIds.add(act.id);
            }
            _isFirstLoad = false;
          } else {
            for (final act in activities) {
              if (!_seenActivityIds.contains(act.id)) {
                _seenActivityIds.add(act.id);
                _triggerLocalNotification(act);
              }
            }
          }

          _lastActivities = activities;
          state = AsyncData(activities);
        } catch (e) {
          debugPrint('[ACTIVITY STREAM] parse error: $e');
          if (_lastActivities.isNotEmpty) {
            state = AsyncData(_lastActivities);
          } else if (state is! AsyncData) {
            state = AsyncData([]);
          }
        }
      },
      onError: (e) {
        debugPrint('[ACTIVITY STREAM ERROR] $e');
        if (_lastActivities.isNotEmpty) {
          state = AsyncData(_lastActivities);
        } else if (state is! AsyncData) {
          state = AsyncData([]);
        }
      },
    );
    ref.onDispose(() {
      debugPrint('[ACTIVITY DISPOSED]');
      _subscription?.cancel();
    });

    if (_lastActivities.isNotEmpty) {
      debugPrint('[ACTIVITY BUILD] returning CACHED ${_lastActivities.length} activities');
      return _lastActivities;
    }

    try {
      final response = await SupabaseService.instance
          .from('activities')
          .select()
          .eq('user_id', uid)
          .neq('type', 'support_ticket')
          .order('created_at', ascending: false)
          .limit(10)
          .timeout(const Duration(seconds: 15));
      final result = (response as List).map((e) => Activity.fromJson(e)).toList();
      debugPrint('[ACTIVITY BUILD] initial fetch: ${result.length} activities');
      _lastActivities = result;
      return result;
    } catch (e) {
      debugPrint('[ACTIVITY BUILD] fetch failed: $e');
      return [];
    }
  }

  Future<void> clearAll() async {
    final authState = ref.read(authProvider);
    final uid = authState.user?.id ?? SupabaseService.userId;
    state = const AsyncData([]);
    _lastActivities = [];
    await SupabaseService.instance
        .from('activities')
        .delete()
        .eq('user_id', uid)
        .neq('type', 'support_ticket');
  }
}

// ─── Overdue Check ────────────────────────────────────────────────────

bool isProjectOverdue(Project p) =>
    p.deadline != null && p.deadline!.isBefore(DateTime.now()) && p.status != ProjectStatus.paid;

// ─── Pipeline Map ─────────────────────────────────────────────────────

final pipelineMapProvider = Provider<Map<ProjectStatus, int>>((ref) {
  final projects = ref.watch(safeProjectsProvider);
  return {
    for (final status in ProjectStatus.values)
      status: projects.where((p) => p.status == status).length,
  };
});

// ─── Client Metrics ───────────────────────────────────────────────────

class ClientMetrics {
  final double totalValue;
  final double revenue;
  final double pending;
  final int projectCount;

  const ClientMetrics({
    required this.totalValue,
    required this.revenue,
    required this.pending,
    required this.projectCount,
  });
}

final clientMetricsProvider = Provider.family<ClientMetrics, String>((ref, clientId) {
  final projects = ref.watch(safeProjectsProvider);
  final clientProjects = projects.where((p) => p.clientId == clientId).toList();
  return ClientMetrics(
    totalValue: clientProjects.fold<double>(0.0, (s, p) => s + p.price),
    revenue: clientProjects.fold<double>(0.0, (s, p) => s + p.receivedAmount),
    pending: clientProjects.fold<double>(0.0, (s, p) => s + p.remainingAmount),
    projectCount: clientProjects.length,
  );
});

// ─── Client List Data ─────────────────────────────────────────────────

class ClientListData {
  final Client client;
  final double revenue;
  final double pending;
  final int projectCount;

  const ClientListData({
    required this.client,
    required this.revenue,
    required this.pending,
    required this.projectCount,
  });
}

final clientListDataProvider = Provider<List<ClientListData>>((ref) {
  final clients = ref.watch(safeClientsProvider);
  final projects = ref.watch(safeProjectsProvider);
  return clients.map((client) {
    final clientProjects = projects.where((p) => p.clientId == client.id).toList();
    return ClientListData(
      client: client,
      revenue: clientProjects.fold<double>(0.0, (s, p) => s + p.price),
      pending: clientProjects.fold<double>(0.0, (s, p) => s + p.remainingAmount),
      projectCount: clientProjects.length,
    );
  }).toList();
});

// ─── Dashboard Metrics ────────────────────────────────────────────────

class DashboardMetrics {
  final double totalRevenue;
  final double totalReceived;
  final double totalPending;
  final double totalOverdue;
  final int activeProjects;
  final int totalClients;
  final int paidCount;
  final double avgProjectValue;
  final double completionRate;
  final int weekStarted;
  final int weekPaid;
  final double weekPayments;
  final List<double> weeklyRevenue;
  final List<double> monthlyRevenue;
  final List<double> yearlyRevenue;
  final Map<ProjectStatus, int> pipelineMap;
  final List<TopClientEntry> topClients;
  final List<TopFreelancerEntry> topFreelancers;

  const DashboardMetrics({
    required this.totalRevenue,
    required this.totalReceived,
    required this.totalPending,
    required this.totalOverdue,
    required this.activeProjects,
    required this.totalClients,
    required this.paidCount,
    required this.avgProjectValue,
    required this.completionRate,
    required this.weekStarted,
    required this.weekPaid,
    required this.weekPayments,
    required this.weeklyRevenue,
    required this.monthlyRevenue,
    required this.yearlyRevenue,
    required this.pipelineMap,
    required this.topClients,
    required this.topFreelancers,
  });
}

class TopClientEntry {
  final Client client;
  final double revenue;
  final double percentage;
  const TopClientEntry({
    required this.client,
    required this.revenue,
    required this.percentage,
  });
}

class TopFreelancerEntry {
  final String id;
  final String name;
  final int activeProjectsCount;
  final int matchingDeadlinesCount;
  final DateTime? nextDeadline;

  const TopFreelancerEntry({
    required this.id,
    required this.name,
    required this.activeProjectsCount,
    required this.matchingDeadlinesCount,
    this.nextDeadline,
  });
}

final dashboardMetricsProvider = Provider<DashboardMetrics>((ref) {
  final projects = ref.watch(safeProjectsProvider);
  final clients = ref.watch(safeClientsProvider);
  debugPrint('[DASHBOARD METRICS] projects=${projects.length} clients=${clients.length}');
  return _computeDashboardMetrics(projects, clients);
});

DashboardMetrics _computeDashboardMetrics(List<Project> projects, List<Client> clients) {
  final totalRevenue = projects.fold<double>(0.0, (s, p) => s + p.price);
  final totalReceived = projects.fold<double>(0.0, (s, p) => s + p.receivedAmount);
  final totalPending = projects.fold<double>(0.0, (s, p) => s + p.remainingAmount);
  final activeProjects = projects
      .where((p) => p.status == ProjectStatus.inProgress || p.status == ProjectStatus.revisionPending)
      .length;
  final totalClients = clients.length;
  final paidCount = projects.where((p) => p.status == ProjectStatus.paid).length;
  final avgProjectValue = projects.isNotEmpty ? totalRevenue / projects.length : 0.0;
  final completionRate = projects.isNotEmpty ? paidCount / projects.length * 100 : 0.0;
  final today = DateTime.now();

  final weekStart = DateTime(today.year, today.month, today.day)
      .subtract(Duration(days: DateTime(today.year, today.month, today.day).weekday - 1));
  final weekEnd = weekStart.add(const Duration(days: 7));

  int weekStarted = 0, weekPaid = 0;
  double weekPayments = 0;
  for (final p in projects) {
    if (p.createdAt.isAfter(weekStart) && p.createdAt.isBefore(weekEnd)) {
      weekStarted++;
      if (p.status == ProjectStatus.paid) {
        weekPaid++;
      }
      weekPayments += p.receivedAmount;
    }
  }

  final weeklyRevenue = List.generate(7, (i) {
    final day = weekStart.add(Duration(days: i));
    return projects
        .where((p) =>
            p.createdAt.year == day.year &&
            p.createdAt.month == day.month &&
            p.createdAt.day == day.day)
        .fold<double>(0.0, (s, p) => s + p.receivedAmount);
  });

  final monthlyRevenue = List.generate(30, (i) {
    final day = today.subtract(Duration(days: 29 - i));
    return projects
        .where((p) =>
            p.createdAt.year == day.year &&
            p.createdAt.month == day.month &&
            p.createdAt.day == day.day)
        .fold<double>(0.0, (s, p) => s + p.receivedAmount);
  });

  final yearlyRevenue = List.generate(12, (i) {
    final month = today.month - 11 + i;
    final adjustedMonth = ((month - 1) % 12) + 1;
    final year = month <= 0 ? today.year - 1 + ((month - 1) ~/ 12) : today.year;
    return projects
        .where((p) => p.createdAt.year == year && p.createdAt.month == adjustedMonth)
        .fold<double>(0.0, (s, p) => s + p.receivedAmount);
  });

  final pipelineMap = {
    for (final status in ProjectStatus.values)
      status: projects.where((p) => p.status == status).length,
  };

  final totalOverdue = projects
      .where((p) => isProjectOverdue(p))
      .fold<double>(0.0, (s, p) => s + p.remainingAmount);

  final clientRevenue = <String, double>{};
  for (final p in projects) {
    clientRevenue[p.clientId] = (clientRevenue[p.clientId] ?? 0.0) + p.price;
  }
  final sortedClients = clientRevenue.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final topClients = sortedClients.take(3).map((e) {
    final client = clients.firstWhere(
      (c) => c.id == e.key,
      orElse: () => Client(id: e.key, userId: '', name: 'Unknown', createdAt: today, updatedAt: today),
    );
    return TopClientEntry(
      client: client,
      revenue: e.value,
      percentage: totalRevenue > 0 ? (e.value / totalRevenue * 100) : 0.0,
    );
  }).toList();

  // Compute Top Freelancers based on matching deadlines
  final freelancerProjects = <String, List<Project>>{};
  for (final p in projects) {
    final fid = p.userId;
    if (freelancerProjects[fid] == null) {
      freelancerProjects[fid] = [];
    }
    freelancerProjects[fid]!.add(p);
  }

  final topFreelancers = freelancerProjects.entries.map((entry) {
    final fid = entry.key;
    final fprojects = entry.value;
    
    // Find the first non-null freelancerName from projects
    String? name;
    for (final p in fprojects) {
      if (p.freelancerName != null && p.freelancerName!.isNotEmpty) {
        name = p.freelancerName;
        break;
      }
    }
    name ??= 'Freelancer';
    
    final activeCount = fprojects.where((p) => p.status != ProjectStatus.paid).length;
    
    // Deadlines that are upcoming (in the future)
    final upcomingDeadlines = fprojects
        .where((p) => p.deadline != null && p.deadline!.isAfter(today) && p.status != ProjectStatus.paid)
        .toList();
        
    upcomingDeadlines.sort((a, b) => a.deadline!.compareTo(b.deadline!));
    final nextDeadline = upcomingDeadlines.isNotEmpty ? upcomingDeadlines.first.deadline : null;

    return TopFreelancerEntry(
      id: fid,
      name: name,
      activeProjectsCount: activeCount,
      matchingDeadlinesCount: upcomingDeadlines.length,
      nextDeadline: nextDeadline,
    );
  }).toList();
  
  // Sort by matching deadlines count descending, then active projects count descending
  topFreelancers.sort((a, b) {
    final cmp = b.matchingDeadlinesCount.compareTo(a.matchingDeadlinesCount);
    if (cmp != 0) return cmp;
    return b.activeProjectsCount.compareTo(a.activeProjectsCount);
  });

  return DashboardMetrics(
    totalRevenue: totalRevenue,
    totalReceived: totalReceived,
    totalPending: totalPending,
    totalOverdue: totalOverdue,
    activeProjects: activeProjects,
    totalClients: totalClients,
    paidCount: paidCount,
    avgProjectValue: avgProjectValue,
    completionRate: completionRate,
    weekStarted: weekStarted,
    weekPaid: weekPaid,
    weekPayments: weekPayments,
    weeklyRevenue: weeklyRevenue,
    monthlyRevenue: monthlyRevenue,
    yearlyRevenue: yearlyRevenue,
    pipelineMap: pipelineMap,
    topClients: topClients,
    topFreelancers: topFreelancers,
  );
}

// ─── Period Metrics ────────────────────────────────────────────────────

class PeriodMetricItem {
  final String label;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final double? progressRatio;
  const PeriodMetricItem({
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor,
    this.progressRatio,
  });
}

enum DashboardPeriod { all, month, year }

final dashboardPeriodMetricsProvider =
    Provider.family<List<PeriodMetricItem>, DashboardPeriod>((ref, period) {
  final projects = ref.watch(safeProjectsProvider);
  final currency = ref.watch(currencyProvider);
  final settings = ref.watch(settingsProvider);
  final isClient = settings.isClientMode;
  final now = DateTime.now();

  Iterable<Project> filtered;
  switch (period) {
    case DashboardPeriod.month:
      final start = DateTime(now.year, now.month, 1);
      final end = now.month == 12 ? DateTime(now.year + 1, 1, 1) : DateTime(now.year, now.month + 1, 1);
      filtered = projects.where((p) => p.createdAt.isAfter(start) && p.createdAt.isBefore(end));
    case DashboardPeriod.year:
      final start = DateTime(now.year, 1, 1);
      final end = DateTime(now.year + 1, 1, 1);
      filtered = projects.where((p) => p.createdAt.isAfter(start) && p.createdAt.isBefore(end));
    case DashboardPeriod.all:
      filtered = projects;
  }

  final list = filtered.toList();
  final earning = list.fold<double>(0.0, (s, p) => s + p.price);
  final paid = list.fold<double>(0.0, (s, p) => s + p.receivedAmount);
  final pending = list.fold<double>(0.0, (s, p) => s + p.remainingAmount);
  final overdue = projects
      .where((p) => isProjectOverdue(p))
      .fold<double>(0.0, (s, p) => s + p.remainingAmount);

  return [
    PeriodMetricItem(
      label: isClient ? 'Total Expense' : 'Earning',
      value: currency.format(earning),
      icon: Icons.trending_up_rounded,
      iconColor: const Color(0xFF22C55E),
      progressRatio: !isClient && settings.monthlyGoal > 0 ? (earning / settings.monthlyGoal).clamp(0.0, 1.0) : 0.6,
    ),
    PeriodMetricItem(
      label: isClient ? 'Total Paid' : 'Paid',
      value: currency.format(paid),
      icon: Icons.check_circle_rounded,
      iconColor: AppColors.primaryNeon,
      progressRatio: earning > 0 ? (paid / earning).clamp(0.0, 1.0) : 0.0,
    ),
    PeriodMetricItem(
      label: isClient ? 'Total Due' : 'Pending',
      value: currency.format(pending),
      icon: Icons.hourglass_empty_rounded,
      iconColor: const Color(0xFFF59E0B),
      progressRatio: earning > 0 ? (pending / earning).clamp(0.0, 1.0) : 0.0,
    ),
    PeriodMetricItem(
      label: isClient ? 'Overdue' : 'Overdue',
      value: currency.format(overdue),
      icon: Icons.warning_rounded,
      iconColor: const Color(0xFFEF4444),
      progressRatio: earning > 0 ? (overdue / earning).clamp(0.0, 1.0) : 0.0,
    ),
  ];
});

// ─── Payment Overview Metrics ─────────────────────────────────────────

class PaymentOverviewMetrics {
  final double totalAmount;
  final double receivedAmount;
  final double remaining;
  final List<Project> overdueProjects;
  final List<Project> paidProjects;

  const PaymentOverviewMetrics({
    required this.totalAmount,
    required this.receivedAmount,
    required this.remaining,
    required this.overdueProjects,
    required this.paidProjects,
  });
}

final paymentOverviewProvider = Provider<PaymentOverviewMetrics>((ref) {
  final projects = ref.watch(safeProjectsProvider);
  return PaymentOverviewMetrics(
    totalAmount: projects.fold<double>(0.0, (s, p) => s + p.price),
    receivedAmount: projects.fold<double>(0.0, (s, p) => s + p.receivedAmount),
    remaining: projects.fold<double>(0.0, (s, p) => s + p.remainingAmount),
    overdueProjects: projects.where((p) => isProjectOverdue(p)).toList(),
    paidProjects: projects.where((p) => p.status == ProjectStatus.paid).toList(),
  );
});

// ─── Calendar Deadlines ───────────────────────────────────────────────

final calendarDeadlinesProvider = Provider<List<Project>>((ref) {
  final projects = ref.watch(safeProjectsProvider);
  return projects.where((p) => p.deadline != null && p.status != ProjectStatus.paid).toList();
});

final projectDetailProvider = FutureProvider.family<Project, String>((ref, id) async {
  final projects = ref.watch(safeProjectsProvider);
  for (final p in projects) {
    if (p.id == id) return p;
  }
  final repo = ref.watch(projectRepositoryProvider);
  return repo.getById(id);
});

final freelancerProjectsProvider = Provider.family<List<Project>, String>((ref, freelancerId) {
  final projects = ref.watch(safeProjectsProvider);
  return projects.where((p) => p.userId == freelancerId).toList();
});
