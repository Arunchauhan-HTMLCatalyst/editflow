import '../../services/supabase_service.dart';

class ActivityService {
  Future<void> log({
    required String type,
    required String description,
    String? referenceId,
    String? referenceType,
  }) async {
    await SupabaseService.instance
        .from('activities')
        .insert({
          'user_id': SupabaseService.userId,
          'type': type,
          'description': description,
          'reference_id': referenceId,
          'reference_type': referenceType,
        })
        .timeout(const Duration(seconds: 15));
  }
}
