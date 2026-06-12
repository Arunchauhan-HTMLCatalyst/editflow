import 'dart:async';
import '../../../services/supabase_service.dart';
import '../../projects/models/project.dart';
import '../../../shared/services/activity_service.dart';

class ProjectRepository {
  final ActivityService _activity = ActivityService();

  Future<List<Project>> getAll() async {
    final userId = SupabaseService.userId;
    final response = await SupabaseService.instance
        .from('projects')
        .select('*, clients!inner(name)')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .timeout(const Duration(seconds: 15));
    return (response as List)
        .map((e) => Project.tryFromJson(e))
        .whereType<Project>()
        .toList();
  }

  Future<List<Project>> getByClientId(String clientId) async {
    final userId = SupabaseService.userId;
    final response = await SupabaseService.instance
        .from('projects')
        .select('*, clients!inner(name)')
        .eq('user_id', userId)
        .eq('client_id', clientId)
        .order('created_at', ascending: false)
        .timeout(const Duration(seconds: 15));
    return (response as List)
        .map((e) => Project.tryFromJson(e))
        .whereType<Project>()
        .toList();
  }

  Future<Project> getById(String id) async {
    final response = await SupabaseService.instance
        .from('projects')
        .select('*, clients!inner(name)')
        .eq('id', id)
        .single()
        .timeout(const Duration(seconds: 15));
    if (response['clients'] != null) {
      response['client_name'] = response['clients']['name'];
    }
    return Project.fromJson(response);
  }

  Future<Project> create(Project project) async {
    final data = project.toJson()..remove('id')..remove('client_name');
    final response = await SupabaseService.instance
        .from('projects')
        .insert(data)
        .select()
        .single()
        .timeout(const Duration(seconds: 15));
    final created = Project.fromJson(response);
    unawaited(_activity.log(
      type: 'project_created',
      description: 'Created project "${created.name}"',
      referenceId: created.id,
      referenceType: 'project',
    ));
    return created;
  }

  Future<Project> update(Project project) async {
    final data = project.toJson()..remove('client_name');
    final response = await SupabaseService.instance
        .from('projects')
        .update(data)
        .eq('id', project.id)
        .select()
        .single()
        .timeout(const Duration(seconds: 15));
    return Project.fromJson(response);
  }

  Future<void> delete(String id) async {
    await SupabaseService.instance
        .from('projects')
        .delete()
        .eq('id', id)
        .timeout(const Duration(seconds: 15));
  }

  Future<void> logStatusChange({
    required String type,
    required String description,
    required String projectId,
  }) async {
    await _activity.log(
      type: type,
      description: description,
      referenceId: projectId,
      referenceType: 'project',
    );
  }
}
