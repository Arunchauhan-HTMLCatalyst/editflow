import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import '../models/project_status.dart';
import '../repositories/project_repository.dart';
import '../repositories/client_project_repository.dart';
import '../../settings/providers/settings_provider.dart';
import '../../../services/supabase_service.dart';
import '../../../shared/services/activity_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/providers/computed_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ProjectProvider extends AsyncNotifier<List<Project>> {
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  List<Project> _lastValidData = [];
  bool _hasLoadedOnce = false;
  Timer? _periodicTimer;
  bool? _lastIsClient;

  List<Project> _sort(List<Project> projects) {
    return List.from(projects)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  String _getCacheKey() {
    final settings = ref.read(settingsProvider);
    final isClient = settings.isClientMode;
    final authState = ref.read(authProvider);
    final uid = authState.user?.id ?? SupabaseService.userId;
    return isClient ? 'cached_projects_client_$uid' : 'cached_projects_freelancer_$uid';
  }

  @override
  Future<List<Project>> build() async {
    final settings = ref.watch(settingsProvider);
    final isClient = settings.isClientMode;

    if (_lastIsClient != isClient) {
      debugPrint('[PROJECT BUILD] client mode changed from $_lastIsClient to $isClient - clearing cache');
      _lastIsClient = isClient;
      _hasLoadedOnce = false;
      _lastValidData = [];
    }

    final repo = ref.watch(projectRepositoryProvider);
    final authState = ref.watch(authProvider);

    if (authState.status != AuthStatus.authenticated) {
      debugPrint('[PROJECT BUILD] not authenticated - clearing cache');
      _lastValidData = [];
      _hasLoadedOnce = false;
      _periodicTimer?.cancel();
      return [];
    }

    final uid = authState.user?.id ?? SupabaseService.userId;
    debugPrint('[PROJECT BUILD] uid=$uid hasLoaded=$_hasLoadedOnce cacheLen=${_lastValidData.length}');

    final cacheKey = isClient ? 'cached_projects_client_$uid' : 'cached_projects_freelancer_$uid';

    // Set up a periodic timer to automatically refresh data every 2.5 minutes on Web
    if (kIsWeb && (_periodicTimer == null || !_periodicTimer!.isActive)) {
      debugPrint('[PROJECT PROVIDER] Starting global periodic 2.5m auto-refresh');
      _periodicTimer = Timer.periodic(const Duration(minutes: 2, seconds: 30), (t) {
        debugPrint('[PROJECT PROVIDER] Periodic 2.5m auto-refresh triggered');
        _backgroundRefresh(cacheKey, repo);
      });
      ref.onDispose(() {
        _periodicTimer?.cancel();
        _periodicTimer = null;
      });
    }

    ref.onDispose(() {
      debugPrint('[PROJECT DISPOSED]');
      _subscription?.cancel();
      _periodicTimer?.cancel();
      _periodicTimer = null;
    });

    if (_hasLoadedOnce) {
      debugPrint('[PROJECT BUILD] returning CACHED ${_lastValidData.length} projects and triggering background refresh');
      _backgroundRefresh(cacheKey, repo);
      return _lastValidData;
    }

    // 1. Try to load from SharedPreferences cache first
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(cacheKey);
      if (cachedJson != null) {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        final list = decoded.map((e) => Project.fromJson(e)).toList();
        _lastValidData = list;
        _hasLoadedOnce = true;
        
        debugPrint('[PROJECT BUILD] Loaded ${list.length} projects from local storage cache. Starting delayed background refresh.');
        
        // Start background refresh. In tests, run immediately to avoid pumpAndSettle timeout.
        if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
          _backgroundRefresh(cacheKey, repo);
        } else {
          var disposed = false;
          ref.onDispose(() => disposed = true);
          final refreshDelay = kIsWeb ? 1500 : 600;
          Future.delayed(Duration(milliseconds: refreshDelay), () {
            if (!disposed) {
              _backgroundRefresh(cacheKey, repo);
            }
          });
        }
        
        _setupRealtimeSubscription(cacheKey, repo);
        return list;
      }
    } catch (e) {
      debugPrint('[PROJECT BUILD] local cache load failed: $e');
    }

    // 2. If no cache, fetch from Supabase
    try {
      final fetched = await repo.getAll();
      debugPrint('[PROJECT BUILD] FETCH COUNT=${fetched.length}');
      _lastValidData = fetched;
      _hasLoadedOnce = true;
      _saveToCache(cacheKey, fetched);
      unawaited(_syncProjectNotifications(uid, fetched));
      _setupRealtimeSubscription(cacheKey, repo);
      return fetched;
    } catch (e) {
      debugPrint('[PROJECT BUILD] FETCH FAILED: $e');
      if (_lastValidData.isNotEmpty) {
        return _lastValidData;
      }
      rethrow;
    }
  }

  bool _areProjectListsEqual(List<Project> a, List<Project> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      final pA = a[i];
      final pB = b[i];
      if (pA.id != pB.id ||
          pA.name != pB.name ||
          pA.description != pB.description ||
          pA.price != pB.price ||
          pA.receivedAmount != pB.receivedAmount ||
          pA.deadline != pB.deadline ||
          pA.status != pB.status ||
          pA.updatedAt != pB.updatedAt ||
          pA.clientName != pB.clientName ||
          pA.freelancerName != pB.freelancerName ||
          pA.paymentType != pB.paymentType ||
          pA.isFolder != pB.isFolder ||
          pA.parentId != pB.parentId ||
          pA.reviewStatus != pB.reviewStatus) {
        return false;
      }
    }
    return true;
  }

  Future<void> _backgroundRefresh(String cacheKey, ProjectRepository repo) async {
    try {
      final fetched = await repo.getAll();
      _saveToCache(cacheKey, fetched);

      final currentList = state.valueOrNull ?? [];
      if (!_areProjectListsEqual(currentList, fetched)) {
        debugPrint('[PROJECT BG REFRESH] data changed - updating state');
        _lastValidData = fetched;
        _hasLoadedOnce = true;
        state = AsyncData(fetched);
      } else {
        debugPrint('[PROJECT BG REFRESH] no changes detected - skipping state update');
      }
      
      final authState = ref.read(authProvider);
      final uid = authState.user?.id ?? SupabaseService.userId;
      unawaited(_syncProjectNotifications(uid, fetched));
    } catch (e) {
      debugPrint('[PROJECT BG REFRESH] failed: $e');
    }
  }

  void _setupRealtimeSubscription(String cacheKey, ProjectRepository repo) {
    if (_subscription != null) return;
    _subscription = SupabaseService.instance
        .from('projects')
        .stream(primaryKey: ['id'])
        .skip(1)
        .listen((_) {
          debugPrint('[PROJECT REALTIME] Change detected, refreshing...');
          _backgroundRefresh(cacheKey, repo);
        }, onError: (e) {
          debugPrint('[PROJECT REALTIME] Error: $e');
        });
  }

  Future<void> _syncProjectNotifications(String currentUserId, List<Project> projects) async {
    try {
      final now = DateTime.now();
      for (final p in projects) {
        if (p.deadline == null) continue;
        final remaining = p.deadline!.difference(now);

        // Determine if we need due date notifications
        final isPendingOrActive = p.status != ProjectStatus.reviewPending &&
            p.status != ProjectStatus.revisionPending &&
            p.status != ProjectStatus.completed &&
            p.status != ProjectStatus.paid;

        String? neededType;
        String? desc;

        if (isPendingOrActive) {
          if (remaining.isNegative) {
            neededType = 'due_date_overdue';
            desc = 'Project "${p.name}" is overdue!';
          } else if (remaining.inHours <= 12) {
            neededType = 'due_date_12h';
            desc = 'Project "${p.name}" is due in less than 12 hours!';
          } else if (remaining.inHours <= 24) {
            neededType = 'due_date_1d';
            desc = 'Project "${p.name}" is due in less than 24 hours!';
          } else if (remaining.inHours <= 48) {
            neededType = 'due_date_2d';
            desc = 'Project "${p.name}" is due in less than 2 days!';
          }
        }

        // Determine if overdue payment
        if (p.remainingAmount > 0 && remaining.isNegative && p.status != ProjectStatus.paid) {
          if (p.status == ProjectStatus.completed) {
            neededType = 'payment_overdue';
            desc = 'Payment for completed project "${p.name}" is overdue!';
          }
        }

        if (neededType != null && desc != null) {
          final existing = await SupabaseService.instance
              .from('activities')
              .select('id')
              .eq('user_id', currentUserId)
              .eq('type', neededType)
              .eq('reference_id', p.id);

          if ((existing as List).isEmpty) {
            await SupabaseService.instance.from('activities').insert({
              'user_id': currentUserId,
              'type': neededType,
              'description': desc,
              'reference_id': p.id,
              'reference_type': 'project',
              'created_at': now.toIso8601String(),
            });
            debugPrint('[NOTIFICATION SYNC] Logged notification "$neededType" for project ${p.name}');
          }
        }
      }
    } catch (e) {
      debugPrint('[NOTIFICATION SYNC ERROR] $e');
    }
  }

  Future<void> _saveToCache(String cacheKey, List<Project> projects) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(projects.map((p) => p.toJson()).toList());
      await prefs.setString(cacheKey, jsonStr);
    } catch (e) {
      debugPrint('[PROJECT CACHE] Save failed: $e');
    }
  }

  Future<void> addProject(Project project) async {
    final repo = ref.read(projectRepositoryProvider);
    final previousState = state.valueOrNull ?? [];

    try {
      final newProject = await repo.create(project);

      // If we are in client mode, notify the freelancer
      final isClient = ref.read(settingsProvider).isClientMode;
      if (isClient) {
        unawaited(() async {
          try {
            final clients = ref.read(safeClientsProvider);
            final client = clients.firstWhere((c) => c.id == newProject.clientId);
            final clientName = client.name;

            await SupabaseService.instance.from('activities').insert({
              'user_id': newProject.userId,
              'type': 'project_created',
              'description': 'Client "$clientName" assigned you a new project: "${newProject.name}"',
              'reference_id': newProject.id,
              'reference_type': 'project',
              'created_at': DateTime.now().toIso8601String(),
            });

            await SupabaseService.instance.functions.invoke(
              'send-push',
              body: {
                'recipientUserId': newProject.userId,
                'title': 'New Project Assigned',
                'body': 'Client "$clientName" assigned you a new project: "${newProject.name}"',
                'route': '/projects/${newProject.id}',
              },
            );

            debugPrint('[PROJECT NOTIFICATION] Sent notification to freelancer ${newProject.userId} for project ${newProject.name}');
          } catch (err) {
            debugPrint('[PROJECT NOTIFICATION ERROR] $err');
          }
        }());
      }

      if (newProject.parentId != null) {
        ref.invalidate(subProjectsProvider(newProject.parentId!));
        state = AsyncData(previousState);
      } else {
        final updatedList = _sort([newProject, ...previousState]);
        _lastValidData = updatedList;
        state = AsyncData(updatedList);
        _saveToCache(_getCacheKey(), updatedList);
      }
      debugPrint('[ProjectProvider] addProject: created ${newProject.id}');
    } catch (e, st) {
      debugPrint('[ProjectProvider] addProject failed: $e');
      state = AsyncError<List<Project>>(e, st).copyWithPrevious(AsyncData(previousState));
      rethrow;
    }
  }

  Future<void> updateProject(Project project) async {
    final repo = ref.read(projectRepositoryProvider);
    final previousState = state.valueOrNull ?? [];
    final isSubProject = project.parentId != null;

    if (!isSubProject) {
      final optimistic = previousState.map((p) => p.id == project.id ? project : p).toList();
      _lastValidData = optimistic;
      state = AsyncData(optimistic);
    }

    try {
      final updated = await repo.update(project);
      
      if (isSubProject) {
        ref.invalidate(projectDetailProvider(updated.id));
        ref.invalidate(subProjectsProvider(updated.parentId!));
      } else {
        final current = state.valueOrNull ?? [];
        final updatedList = current.map((p) => p.id == updated.id ? updated : p).toList();
        _lastValidData = updatedList;
        state = AsyncData(updatedList);
        _saveToCache(_getCacheKey(), updatedList);
      }
      debugPrint('[ProjectProvider] updateProject: updated ${updated.id}');

      // If in client mode, notify the freelancer of the edit. If NOT, notify the client.
      final isClient = ref.read(settingsProvider).isClientMode;
      if (isClient) {
        unawaited(() async {
          try {
            final clients = ref.read(safeClientsProvider);
            final client = clients.firstWhereOrNull((c) => c.id == updated.clientId);
            final clientName = client?.name ?? 'Client';

            await SupabaseService.instance.from('activities').insert({
              'user_id': updated.userId,
              'type': 'project_updated',
              'description': 'Client "$clientName" updated project: "${updated.name}"',
              'reference_id': updated.id,
              'reference_type': 'project',
              'created_at': DateTime.now().toIso8601String(),
            });

            await SupabaseService.instance.functions.invoke(
              'send-push',
              body: {
                'recipientUserId': updated.userId,
                'title': 'Project Updated',
                'body': 'Client "$clientName" updated project: "${updated.name}"',
                'route': '/projects/${updated.id}',
              },
            );

            debugPrint('[PROJECT NOTIFICATION] Sent update notification to freelancer ${updated.userId} for project ${updated.name}');
          } catch (err) {
            debugPrint('[PROJECT NOTIFICATION ERROR] $err');
          }
        }());
      } else {
        // Freelancer edited → notify client
        unawaited(() async {
          try {
            final clients = ref.read(safeClientsProvider);
            final client = clients.firstWhereOrNull((c) => c.id == updated.clientId);
            if (client != null && client.clientUserId != null) {
              final freelancerName = ref.read(authProvider).user?.userMetadata?['full_name'] ?? 'Freelancer';

              await SupabaseService.instance.from('activities').insert({
                'user_id': client.clientUserId!,
                'type': 'project_updated',
                'description': 'Freelancer "$freelancerName" updated project: "${updated.name}"',
                'reference_id': updated.id,
                'reference_type': 'project',
                'created_at': DateTime.now().toIso8601String(),
              });

              await SupabaseService.instance.functions.invoke(
                'send-push',
                body: {
                  'recipientUserId': client.clientUserId!,
                  'title': 'Project Updated',
                  'body': 'Freelancer "$freelancerName" updated project: "${updated.name}"',
                  'route': '/projects/${updated.id}',
                },
              );

              debugPrint('[PROJECT NOTIFICATION] Sent update notification to client ${client.clientUserId} for project ${updated.name}');
            }
          } catch (err) {
            debugPrint('[PROJECT NOTIFICATION ERROR] $err');
          }
        }());
      }
    } catch (e, st) {
      debugPrint('[ProjectProvider] updateProject failed: $e');
      state = AsyncError<List<Project>>(e, st).copyWithPrevious(AsyncData(previousState));
      rethrow;
    }
  }

  Future<void> deleteProject(String id) async {
    final repo = ref.read(projectRepositoryProvider);
    final previousState = state.valueOrNull ?? [];

    try {
      final project = await repo.getById(id);
      await repo.delete(id);
      
      final activity = ActivityService();
      unawaited(activity.log(
        type: 'project_deleted',
        description: 'Deleted project "${project.name}"',
        referenceId: id,
        referenceType: 'project',
      ));

      if (project.parentId != null) {
        ref.invalidate(projectDetailProvider(id));
        ref.invalidate(subProjectsProvider(project.parentId!));
        state = AsyncData(previousState);
      } else {
        final updatedList = previousState.where((p) => p.id != id).toList();
        _lastValidData = updatedList;
        state = AsyncData(updatedList);
        _saveToCache(_getCacheKey(), updatedList);
      }
      debugPrint('[ProjectProvider] deleteProject: deleted $id');
    } catch (e, st) {
      debugPrint('[ProjectProvider] deleteProject failed: $e');
      state = AsyncError<List<Project>>(e, st).copyWithPrevious(AsyncData(previousState));
    }
  }

  Future<void> updateStatus(String id, ProjectStatus newStatus) async {
    final projects = state.valueOrNull ?? [];
    final repo = ref.read(projectRepositoryProvider);
    final previousState = state.valueOrNull ?? [];
    
    // Find the project (either in top-level state or via repository if sub-project)
    Project? project = projects.firstWhereOrNull((p) => p.id == id);
    if (project == null) {
      try {
        project = await repo.getById(id);
      } catch (e) {
        debugPrint('[ProjectProvider] updateStatus failed to fetch project: $e');
        return;
      }
    }

    Project updated;
    if (newStatus == ProjectStatus.paid) {
      updated = project.copyWith(status: newStatus, receivedAmount: project.price);
    } else if (project.status == ProjectStatus.paid) {
      updated = project.copyWith(status: newStatus, receivedAmount: 0);
    } else {
      updated = project.copyWith(status: newStatus);
    }

    final isSubProject = updated.parentId != null;
    
    if (!isSubProject) {
      final optimisticList = projects.map((p) => p.id == id ? updated : p).toList();
      _lastValidData = optimisticList;
      state = AsyncData(optimisticList);
      _saveToCache(_getCacheKey(), optimisticList);
    }

    try {
      final confirmed = await repo.update(updated);
      
      if (isSubProject) {
        ref.invalidate(projectDetailProvider(id));
        ref.invalidate(subProjectsProvider(confirmed.parentId!));
      } else {
        final current = state.valueOrNull ?? [];
        final updatedList = current.map((p) => p.id == confirmed.id ? confirmed : p).toList();
        _lastValidData = updatedList;
        state = AsyncData(updatedList);
        _saveToCache(_getCacheKey(), updatedList);
      }
      debugPrint('[ProjectProvider] updateStatus: $id -> ${newStatus.displayName}');

      final activityType = newStatus == ProjectStatus.paid ? 'payment_received' : 'status_changed';
      final isClient = ref.read(settingsProvider).isClientMode;

      if (isClient) {
        final clients = ref.read(safeClientsProvider);
        final client = clients.firstWhereOrNull((c) => c.id == confirmed.clientId);
        final clientName = client?.name ?? 'Client';

        await SupabaseService.instance.from('activities').insert({
          'user_id': confirmed.userId,
          'type': activityType,
          'description': newStatus == ProjectStatus.paid
              ? 'Client "$clientName" paid retainer amount for project "${confirmed.name}"'
              : 'Client "$clientName" moved project "${confirmed.name}" status to "${newStatus.displayName}"',
          'reference_id': confirmed.id,
          'reference_type': 'project',
          'created_at': DateTime.now().toIso8601String(),
        });

        await SupabaseService.instance.functions.invoke(
          'send-push',
          body: {
            'recipientUserId': confirmed.userId,
            'title': newStatus == ProjectStatus.paid ? 'Payment Received' : 'Status Changed',
            'body': newStatus == ProjectStatus.paid
                ? 'Client "$clientName" paid retainer amount for project "${confirmed.name}"'
                : 'Client "$clientName" moved project "${confirmed.name}" status to "${newStatus.displayName}"',
            'route': '/projects/${confirmed.id}',
          },
        );

        debugPrint('[PROJECT NOTIFICATION] Sent status notification to freelancer ${confirmed.userId} for project ${confirmed.name}');
      } else {
        // Freelancer status change → notify client
        final clients = ref.read(safeClientsProvider);
        final client = clients.firstWhereOrNull((c) => c.id == confirmed.clientId);
        if (client != null && client.clientUserId != null) {
          final freelancerName = ref.read(authProvider).user?.userMetadata?['full_name'] ?? 'Freelancer';

          await SupabaseService.instance.from('activities').insert({
            'user_id': client.clientUserId!,
            'type': activityType,
            'description': newStatus == ProjectStatus.paid
                ? 'Freelancer "$freelancerName" received payment for project "${confirmed.name}"'
                : 'Freelancer "$freelancerName" moved project "${confirmed.name}" status to "${newStatus.displayName}"',
            'reference_id': confirmed.id,
            'reference_type': 'project',
            'created_at': DateTime.now().toIso8601String(),
          });

          await SupabaseService.instance.functions.invoke(
            'send-push',
            body: {
              'recipientUserId': client.clientUserId!,
              'title': newStatus == ProjectStatus.paid ? 'Payment Received' : 'Status Changed',
              'body': newStatus == ProjectStatus.paid
                  ? 'Freelancer "$freelancerName" received payment for project "${confirmed.name}"'
                  : 'Freelancer "$freelancerName" moved project "${confirmed.name}" status to "${newStatus.displayName}"',
              'route': '/projects/${confirmed.id}',
            },
          );

          debugPrint('[PROJECT NOTIFICATION] Sent status notification to client ${client.clientUserId} for project ${confirmed.name}');
        }
      }
    } catch (e, st) {
      debugPrint('[ProjectProvider] updateStatus failed: $e');
      state = AsyncError<List<Project>>(e, st).copyWithPrevious(AsyncData(previousState));
    }
  }

  Future<void> refresh() async {
    final repo = ref.read(projectRepositoryProvider);
    final previousState = state.valueOrNull ?? [];
    debugPrint('[ProjectProvider] refresh() called');
    try {
      final projects = await repo.getAll();
      debugPrint('[ProjectProvider] refresh: got ${projects.length} projects');
      _lastValidData = projects;
      _hasLoadedOnce = true;
      _saveToCache(_getCacheKey(), projects);
      state = AsyncData(projects);
    } catch (e, st) {
      debugPrint('[ProjectProvider] refresh failed: $e');
      state = AsyncError<List<Project>>(e, st).copyWithPrevious(AsyncData(previousState));
    }
  }
}

extension _FirstWhereOrNull<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  final settings = ref.watch(settingsProvider);
  if (settings.isClientMode) {
    return ClientProjectRepository();
  }
  return ProjectRepository();
});

final projectProvider = AsyncNotifierProvider<ProjectProvider, List<Project>>(
  () => ProjectProvider(),
);

final subProjectsProvider = FutureProvider.family<List<Project>, String>((ref, parentId) async {
  final repo = ref.watch(projectRepositoryProvider);
  return repo.getSubProjects(parentId);
});
