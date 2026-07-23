import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'project_repository.dart';
import '../models/project.dart';
import '../../../services/supabase_service.dart';

class ClientProjectRepository extends ProjectRepository {
  @override
  Future<List<Project>> getAll() async {
    final clientUserId = SupabaseService.userId;
    
    try {
      // Fetch projects and clients (to verify user ownership)
      final response = await SupabaseService.instance
          .from('projects')
          .select('*, clients!client_id!inner(name, client_user_id)')
          .eq('clients.client_user_id', clientUserId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 15));
          
      final list = <Project>[];
      for (final e in (response as List)) {
        if (e['clients'] != null) {
          e['client_name'] = e['clients']['name'];
        }
        
        // Fetch freelancer name directly from profiles table using user_id to bypass relationship cache issues
        final freelancerUserId = e['user_id'] as String;
        try {
          final profileRes = await SupabaseService.instance
              .from('profiles')
              .select('full_name')
              .eq('id', freelancerUserId)
              .maybeSingle()
              .timeout(const Duration(seconds: 5));
          if (profileRes != null && profileRes['full_name'] != null) {
            e['freelancer_name'] = profileRes['full_name'] as String;
          }
        } catch (err) {
          debugPrint('[ClientProjectRepository] Freelancer profile fetch failed: $err');
        }
        
        final project = Project.fromJson(e);
        list.add(project);
      }
      return list.where((p) => p.parentId == null).toList();
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
  Future<List<Project>> getSubProjects(String parentId) async {
    final clientUserId = SupabaseService.userId;
    
    try {
      final response = await SupabaseService.instance
          .from('projects')
          .select('*, clients!client_id!inner(name, client_user_id)')
          .eq('clients.client_user_id', clientUserId)
          .eq('parent_id', parentId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 15));
          
      final list = <Project>[];
      for (final e in (response as List)) {
        if (e['clients'] != null) {
          e['client_name'] = e['clients']['name'];
        }
        
        final freelancerUserId = e['user_id'] as String;
        try {
          final profileRes = await SupabaseService.instance
              .from('profiles')
              .select('full_name')
              .eq('id', freelancerUserId)
              .maybeSingle()
              .timeout(const Duration(seconds: 5));
          if (profileRes != null && profileRes['full_name'] != null) {
            e['freelancer_name'] = profileRes['full_name'] as String;
          }
        } catch (err) {
          debugPrint('[ClientProjectRepository] Freelancer profile fetch failed: $err');
        }
        
        final project = Project.fromJson(e);
        list.add(project);
      }
      return list;
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
  Future<void> delete(String id) => throw UnsupportedError("Write operations are disabled in client mode");
}
