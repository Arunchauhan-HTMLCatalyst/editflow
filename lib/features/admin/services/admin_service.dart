import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  static Future<Map<String, dynamic>> invokeAdminAction(String action, [Map<String, dynamic>? payload]) async {
    final response = await Supabase.instance.client.functions.invoke(
      'admin-api',
      body: {
        'action': action,
        'payload': payload ?? {},
      },
    );
    
    if (response.status != 200) {
      final errorMsg = response.data is Map ? response.data['error'] : response.data;
      throw Exception(errorMsg ?? 'Server error ${response.status}');
    }
    
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    
    return {};
  }
}
