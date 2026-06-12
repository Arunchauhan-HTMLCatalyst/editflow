import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';

class SupabaseService {
  static late SupabaseClient client;

  static Future<void> initialize() async {
    debugPrint('[SUPABASE SERVICE] Initializing Supabase...');
    try {
      await Supabase.initialize(
        url: AppConstants.supabaseUrl,
        publishableKey: AppConstants.supabaseAnonKey,
        authOptions: FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      client = Supabase.instance.client;
      debugPrint('[SUPABASE SERVICE] Initialization completed. Session: ${client.auth.currentSession != null ? "active" : "null"}');
    } catch (e, st) {
      debugPrint('[SUPABASE SERVICE] Initialization failed: $e\n$st');
      rethrow;
    }
  }

  static SupabaseClient get instance => client;

  static User? get currentUser => client.auth.currentUser;
  static String get userId {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');
    return user.id;
  }

  static bool get isLoggedIn => currentUser != null;
}
