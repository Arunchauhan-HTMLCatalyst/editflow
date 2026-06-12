import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import '../models/project_status.dart';
import '../repositories/project_repository.dart';
import '../../../services/supabase_service.dart';
import '../../../shared/services/activity_service.dart';
import '../../auth/providers/auth_provider.dart';

class ProjectProvider extends AsyncNotifier<List<Project>> {
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  List<Project> _lastValidData = [];
  bool _hasLoadedOnce = false;

  List<Project> _sort(List<Project> projects) {
    return List.from(projects)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<List<Project>> build() async {
    final repo = ref.watch(projectRepositoryProvider);
    final authState = ref.watch(authProvider);

    if (authState.status != AuthStatus.authenticated) {
      print('[PROJECT BUILD] not authenticated - clearing cache');
      _lastValidData = [];
      _hasLoadedOnce = false;
      return [];
    }

    final uid = authState.user?.id ?? SupabaseService.userId;
    print('[PROJECT BUILD] uid=$uid hasLoaded=$_hasLoadedOnce cacheLen=${_lastValidData.length}');

    // REALTIME DISABLED for isolation test
    // _subscription?.cancel();
    // _subscription = SupabaseService.instance
    //     .from('projects')
    //     .stream(primaryKey: ['id'])
    //     .eq('user_id', uid)
    //     .listen(
    //   (rows) {
    //     print('[PROJECT STREAM] rows=${rows.length}');
    //     if (rows.isNotEmpty) print('  first row keys=${rows.first.keys}');
    //     final projects = <Project>[];
    //     for (final e in rows) {
    //       final p = Project.tryFromJson(e);
    //       if (p != null) {
    //         projects.add(p);
    //       } else {
    //         print('[PROJECT STREAM] SKIPPED invalid row: $e');
    //       }
    //     }
    //     final sorted = _sort(projects);
    //     print('[PROJECT STREAM] parsed ${sorted.length} valid, SETTING STATE');
    //     _lastValidData = sorted;
    //     _hasLoadedOnce = true;
    //     state = AsyncData(sorted);
    //   },
    //   onError: (e) {
    //     print('[PROJECT STREAM ERROR] $e');
    //     if (_hasLoadedOnce) {
    //       state = AsyncData(_lastValidData);
    //     } else {
    //       state = AsyncData([]);
    //     }
    //   },
    // );
    ref.onDispose(() {
      print('[PROJECT DISPOSED]');
      _subscription?.cancel();
    });

    if (_hasLoadedOnce) {
      print('[PROJECT BUILD] returning CACHED ${_lastValidData.length} projects');
      return _lastValidData;
    }

    try {
      final fetched = await repo.getAll();
      print('[PROJECT BUILD] FETCH COUNT=${fetched.length}');
      _lastValidData = fetched;
      _hasLoadedOnce = true;
      return fetched;
    } catch (e, st) {
      print('[PROJECT BUILD] FETCH FAILED: $e');
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
      print('[ProjectProvider] addProject: created ${newProject.id}');
    } catch (e, st) {
      print('[ProjectProvider] addProject failed: $e');
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
      print('[ProjectProvider] updateProject: updated ${updated.id}');
    } catch (e, st) {
      print('[ProjectProvider] updateProject failed: $e');
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
      print('[ProjectProvider] deleteProject: deleted $id');
    } catch (e, st) {
      print('[ProjectProvider] deleteProject failed: $e');
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
      print('[ProjectProvider] updateStatus: $id -> ${newStatus.displayName}');

      final activityType = newStatus == ProjectStatus.paid ? 'payment_received' : 'status_changed';
      await repo.logStatusChange(
        type: activityType,
        description: newStatus == ProjectStatus.paid
            ? 'Payment completed for "${project.name}"'
            : '"${project.name}" -> ${newStatus.displayName}',
        projectId: project.id,
      );
    } catch (e, st) {
      print('[ProjectProvider] updateStatus failed: $e');
      state = AsyncError<List<Project>>(e, st).copyWithPrevious(AsyncData(previousState));
    }
  }

  Future<void> refresh() async {
    final repo = ref.read(projectRepositoryProvider);
    final previousState = state.valueOrNull ?? [];
    print('[ProjectProvider] refresh() called');
    try {
      final projects = await repo.getAll();
      print('[ProjectProvider] refresh: got ${projects.length} projects');
      _lastValidData = projects;
      _hasLoadedOnce = true;
      if (projects.isNotEmpty || previousState.isEmpty) {
        state = AsyncData(projects);
      }
    } catch (e, st) {
      print('[ProjectProvider] refresh failed: $e');
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

final projectRepositoryProvider = Provider<ProjectRepository>((ref) => ProjectRepository());

final projectProvider = AsyncNotifierProvider<ProjectProvider, List<Project>>(
  () => ProjectProvider(),
);
