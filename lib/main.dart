import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'services/supabase_service.dart';
import 'services/local_notification_service.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && Platform.isAndroid) {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (e) {
      debugPrint('[MAIN] Failed to set high display rate: $e');
    }
  }

  try {
    await SupabaseService.initialize();
    await LocalNotificationService.initialize();
  } catch (e, st) {
    debugPrint('[MAIN] Supabase/Notification initialization failed: $e\n$st');
    // App can still run in offline mode for development
  }

  runApp(
    const ProviderScope(
      child: EditFlowApp(),
    ),
  );
}
