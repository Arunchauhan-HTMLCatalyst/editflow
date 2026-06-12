import 'dart:async';
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

class ProjectProvider extends AsyncNotifier<List<Project>> {
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  List<Project> _lastValidData = [];
  bool _hasLoadedOnce = false;
  bool? _lastIsClient;

  List<Project> _sort(List<Project> projects) {
    return List.from(projects)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
      return [];
    }

    final uid = authState.user?.id ?? SupabaseService.userId;
    debugPrint('[PROJECT BUILD] uid=$uid hasLoaded=$_hasLoadedOnce cacheLen=${_lastValidData.length}');

    ref.onDispose(() {
      debugPrint('[PROJECT DISPOSED]');
      _subscription?.cancel();
    });

    if (_hasLoadedOnce) {
      debugPrint('[PROJECT BUILD] returning CACHED ${_lastValidData.length} projects');
      return _lastValidData;
    }

    try {
      final fetched = await repo.getAll();
      debugPrint('[PROJECT BUILD] FETCH COUNT=${fetched.length}');
      _lastValidData = fetched;
      _hasLoadedOnce = true;
      return fetched;
    } catch (e) {
      debugPrint('[PROJECT BUILD] FETCH FAILED: $e');
      if (_lastValidData.isNotEmpty) {
        return _lastValidData;
      }
      rethrow;
    }
  }

  Future<void> addProject(Project project) async {
    final repo = ref.read(projectRepositoryProvider);
    final previousState = state.valueOrNull ?? [];
    final tempProject = project.copyWith(id: '_temp_${DateTime.now().millisecondsSinceEpoch}');

    state = AsyncData([tempProject, ...previousState]);

    try {
      final newProject = await repo.create(project);
      final current = state.valueOrNull ?? [];
      state = AsyncData(_sort([
        newProject,
        ...current.where((p) => p.id != tempProject.id && p.id != newProject.id),
      ]));
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

    final optimistic = previousState.map((p) => p.id == project.id ? project : p).toList();
    state = AsyncData(optimistic);

    try {
      final updated = await repo.update(project);
      final current = state.valueOrNull ?? [];
      state = AsyncData(current.map((p) => p.id == updated.id ? updated : p).toList());
      debugPrint('[ProjectProvider] updateProject: updated ${updated.id}');
    } catch (e, st) {
      debugPrint('[ProjectProvider] updateProject failed: $e');
      state = AsyncError<List<Project>>(e, st).copyWithPrevious(AsyncData(previousState));
      rethrow;
    }
  }

  Future<void> deleteProject(String id) async {
    final repo = ref.read(projectRepositoryProvider);
    final previousState = state.valueOrNull ?? [];
    final projectName = previousState.where((p) => p.id == id).firstOrNull?.name ?? '';

    state = AsyncData(previousState.where((p) => p.id != id).toList());

    try {
      await repo.delete(id);
      final activity = ActivityService();
      unawaited(activity.log(
        type: 'project_deleted',
        description: 'Deleted project "$projectName"',
        referenceId: id,
        referenceType: 'project',
      ));
      debugPrint('[ProjectProvider] deleteProject: deleted $id');
    } catch (e, st) {
      debugPrint('[ProjectProvider] deleteProject failed: $e');
      state = AsyncError<List<Project>>(e, st).copyWithPrevious(AsyncData(previousState));
    }
  }

  Future<void> updateStatus(String id, ProjectStatus newStatus) async {
    final projects = state.valueOrNull ?? [];
    final project = projects.firstWhereOrNull((p) => p.id == id);
    if (project == null) return;

    Project updated;
    if (newStatus == ProjectStatus.paid) {
      updated = project.copyWith(status: newStatus, receivedAmount: project.price);
    } else if (project.status == ProjectStatus.paid) {
      updated = project.copyWith(status: newStatus, receivedAmount: 0);
    } else {
      updated = project.copyWith(status: newStatus);
    }

    final repo = ref.read(projectRepositoryProvider);
    final previousState = state.valueOrNull ?? [];
    state = AsyncData(projects.map((p) => p.id == id ? updated : p).toList());

    try {
      final confirmed = await repo.update(updated);
      final current = state.valueOrNull ?? [];
      state = AsyncData(current.map((p) => p.id == confirmed.id ? confirmed : p).toList());
      debugPrint('[ProjectProvider] updateStatus: $id -> ${newStatus.displayName}');

      final activityType = newStatus == ProjectStatus.paid ? 'payment_received' : 'status_changed';
      await repo.logStatusChange(
        type: activityType,
        description: newStatus == ProjectStatus.paid
            ? 'Payment completed for "${project.name}"'
            : '"${project.name}" -> ${newStatus.displayName}',
        projectId: project.id,
      );
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
      if (projects.isNotEmpty || previousState.isEmpty) {
        state = AsyncData(projects);
      }
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
