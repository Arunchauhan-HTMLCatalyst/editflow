import 'package:supabase_flutter/supabase_flutter.dart';
import 'project_repository.dart';
import '../models/project.dart';
import '../../../services/supabase_service.dart';

class ClientProjectRepository extends ProjectRepository {
  @override
  Future<List<Project>> getAll() async {
    final clientUserId = SupabaseService.userId;
    
    try {
      // Fetch projects, clients (to verify user ownership), and profiles (to get freelancer name)
      final response = await SupabaseService.instance
          .from('projects')
          .select('*, clients!inner(name, client_user_id), profiles:user_id(full_name)')
          .eq('clients.client_user_id', clientUserId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 15));
          
      return (response as List).map((e) {
        if (e['clients'] != null) {
          e['client_name'] = e['clients']['name'];
        }
        if (e['profiles'] != null && e['profiles'] is Map) {
          e['freelancer_name'] = e['profiles']['full_name'];
        }
        return Project.fromJson(e);
      }).toList();
    } on PostgrestException catch (e) {
      if (e.message.contains('client_user_id') || e.code == '42703') {
        throw Exception(
          'Supabase schema missing: The "client_user_id" column does not exist on the "clients" table. '
          'Please run the SQL migration script in your Supabase SQL Editor to enable the Client Portal features.'
        );
      }
      rethrow;
    }
  }

  @override
  Future<List<Project>> getByClientId(String clientId) async {
    // Clients can only fetch their own client ID projects anyway, but we restrict it for safety
    final projects = await getAll();
    return projects.where((p) => p.clientId == clientId).toList();
  }

  @override
  Future<Project> getById(String id) async {
    final project = await super.getById(id);
    // Fetch client record to make sure client owns it
    final clientRow = await SupabaseService.instance
        .from('clients')
        .select('client_user_id')
        .eq('id', project.clientId)
        .single()
        .timeout(const Duration(seconds: 15));

    final clientUserId = clientRow['client_user_id'] as String?;
    if (clientUserId != SupabaseService.userId) {
      throw Exception('Unauthorized access to project');
    }
    return project;
  }

  @override
  Future<Project> create(Project project) => throw UnsupportedError("Write operations are disabled in client mode");

  @override
  Future<Project> update(Project project) => throw UnsupportedError("Write operations are disabled in client mode");

  @override
  Future<void> delete(String id) => throw UnsupportedError("Write operations are disabled in client mode");
}
