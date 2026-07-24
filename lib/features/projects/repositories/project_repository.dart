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
        .select('*, clients!client_id!inner(name)')
        .eq('user_id', userId)
        .isFilter('parent_id', null)
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
        .select('*, clients!client_id!inner(name)')
        .eq('user_id', userId)
        .eq('client_id', clientId)
        .order('created_at', ascending: false)
        .timeout(const Duration(seconds: 15));
    return (response as List)
        .map((e) => Project.tryFromJson(e))
        .whereType<Project>()
        .toList();
  }

  Future<List<Project>> getSubProjects(String parentId) async {
    final userId = SupabaseService.userId;
    final response = await SupabaseService.instance
        .from('projects')
        .select('*, clients!client_id!inner(name)')
        .eq('user_id', userId)
        .eq('parent_id', parentId)
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
        .select('*, clients!client_id!inner(name)')
        .eq('id', id)
        .single()
        .timeout(const Duration(seconds: 15));
    if (response['clients'] != null) {
      response['client_name'] = response['clients']['name'];
    }
    return Project.fromJson(response);
  }

  Future<Project> create(Project project) async {
    final data = project.toJson()
      ..remove('id')
      ..remove('client_name')
      ..remove('freelancer_name')
      ..remove('review_status');
    final response = await SupabaseService.instance
        .from('projects')
        .insert(data)
        .select('*, clients(name)')
        .single()
        .timeout(const Duration(seconds: 15));
    final created = Project.tryFromJson(response) ?? Project.fromJson(response);
    unawaited(_activity.log(
      type: 'project_created',
      description: 'Created project "${created.name}"',
      referenceId: created.id,
      referenceType: 'project',
    ));
    return created;
  }

  Future<Project> update(Project project) async {
    final data = project.toJson()
      ..remove('client_name')
      ..remove('freelancer_name')
      ..remove('review_status');
    final response = await SupabaseService.instance
        .from('projects')
        .update(data)
        .eq('id', project.id)
        .select('*, clients(name)')
        .single()
        .timeout(const Duration(seconds: 15));
    return Project.tryFromJson(response) ?? Project.fromJson(response);
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

  Future<List<Project>> getPendingReviews() async => [];

  Future<void> payRemainingAmount(String projectId, String clientUid) async {
    await SupabaseService.instance.rpc(
      'client_pay_project',
      params: {
        'target_project_id': projectId,
        'client_uid': clientUid,
      },
    );
  }
}
