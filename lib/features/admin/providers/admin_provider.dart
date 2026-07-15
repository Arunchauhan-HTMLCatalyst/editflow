import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/admin_service.dart';

final adminStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return AdminService.invokeAdminAction('get_stats');
});

final adminUsersProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, search) async {
  final res = await AdminService.invokeAdminAction('get_users', {'search': search});
  if (res['users'] is List) {
    return List<Map<String, dynamic>>.from(
      (res['users'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }
  return [];
});

final adminProjectsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await AdminService.invokeAdminAction('get_projects');
  if (res['projects'] is List) {
    return List<Map<String, dynamic>>.from(
      (res['projects'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }
  return [];
});

final adminStorageProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return AdminService.invokeAdminAction('get_storage');
});

final adminSettingsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await AdminService.invokeAdminAction('get_settings');
  if (res['settings'] is List) {
    return List<Map<String, dynamic>>.from(
      (res['settings'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }
  return [];
});

final adminAnalyticsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return AdminService.invokeAdminAction('get_analytics');
});
