import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/supabase_service.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await SupabaseService.initialize();
  } catch (e, st) {
    debugPrint('[MAIN] Supabase initialization failed: $e\n$st');
    // App can still run in offline mode for development
  }

  runApp(
    const ProviderScope(
      child: EditFlowApp(),
    ),
  );
}
