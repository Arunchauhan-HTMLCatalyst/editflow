import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../shared/models/activity.dart';
import 'local_notification_service.dart';

// ─── BACKGROUND ISOLATE ENTRYPOINT ──────────────────────────────────
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(NotificationTaskHandler());
}

class NotificationTaskHandler extends TaskHandler {
  StreamSubscription<List<Map<String, dynamic>>>? _streamSubscription;
  final Set<String> _seenActivityIds = {};
  bool _isFirstLoad = true;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('[FOREGROUND TASK] Background Isolate Started.');
    
    try {
      // 1. Initialize Supabase in Isolate
      await Supabase.initialize(
        url: AppConstants.supabaseUrl,
        publishableKey: AppConstants.supabaseAnonKey,
      );

      // 2. Initialize Local Notifications in Isolate
      await LocalNotificationService.initialize();

      // 3. Connect Stream & Update Dashboard Notification Info
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user != null) {
        debugPrint('[FOREGROUND TASK] User identified: ${user.email}');
        
        // A. Setup Realtime activities listener
        _streamSubscription = client
            .from('activities')
            .stream(primaryKey: ['id'])
            .eq('user_id', user.id)
            .listen(
          (rows) {
            try {
              final activities = rows.map((e) => Activity.fromJson(e)).toList();
              debugPrint('[FOREGROUND TASK STREAM] Received ${activities.length} rows.');
              
              if (_isFirstLoad) {
                // Populate seen cache so we don't trigger alerts for past notifications
                for (final act in activities) {
                  _seenActivityIds.add(act.id);
                }
                _isFirstLoad = false;
                debugPrint('[FOREGROUND TASK STREAM] Initialized seen activities cache.');
              } else {
                for (final act in activities) {
                  if (!_seenActivityIds.contains(act.id)) {
                    _seenActivityIds.add(act.id);
                    _triggerActivityAlert(act);
                  }
                }
              }
            } catch (e) {
              debugPrint('[FOREGROUND TASK STREAM PARSE ERROR] $e');
            }
          },
          onError: (e) {
            debugPrint('[FOREGROUND TASK STREAM ERROR] $e');
          },
        );

        // B. Periodically refresh active project count to update persistent banner stats
        _updateWorkspaceStats(client, user.id);
      } else {
        debugPrint('[FOREGROUND TASK] No logged-in user in isolate context.');
      }
    } catch (e, st) {
      debugPrint('[FOREGROUND TASK START ERROR] $e\n$st');
    }
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    // This runs periodically based on interval setting (e.g. every 30 seconds)
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user != null) {
        await _updateWorkspaceStats(client, user.id);
        await _pollNewActivities(client, user.id);
      }
    } catch (e) {
      debugPrint('[FOREGROUND TASK REPEAT ERROR] $e');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    debugPrint('[FOREGROUND TASK] Isolate Destroyed.');
    await _streamSubscription?.cancel();
  }

  Future<void> _updateWorkspaceStats(SupabaseClient client, String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isClientMode = prefs.getBool('is_client_mode') ?? false;

      if (isClientMode) {
        // Query projects for client (no user_id filter, RLS restricts to client's projects)
        final response = await client
            .from('projects')
            .select('status')
            .timeout(const Duration(seconds: 10));

        final projectList = response as List;
        final activeCount = projectList
            .where((p) => p['status'] != 'completed' && p['status'] != 'paid')
            .length;
        final reviewCount = projectList
            .where((p) => p['status'] == 'review')
            .length;

        await FlutterForegroundTask.updateService(
          notificationTitle: 'EditFlow Client Portal',
          notificationText: 'Pending Review: $reviewCount | Active Projects: $activeCount',
        );
        debugPrint('[FOREGROUND TASK STATS] Client Mode. Review: $reviewCount, Active: $activeCount');
      } else {
        // Query projects for freelancer
        final response = await client
            .from('projects')
            .select('status')
            .eq('user_id', userId)
            .timeout(const Duration(seconds: 10));

        final activeCount = (response as List)
            .where((p) => p['status'] != 'completed' && p['status'] != 'paid')
            .length;

        await FlutterForegroundTask.updateService(
          notificationTitle: 'EditFlow Workspace Dashboard',
          notificationText: 'Active: $activeCount Projects | Running in background',
        );
        debugPrint('[FOREGROUND TASK STATS] Freelancer Mode. Active projects: $activeCount');
      }
    } catch (e) {
      debugPrint('[FOREGROUND TASK STATS ERROR] $e');
    }
  }

  Future<void> _pollNewActivities(SupabaseClient client, String userId) async {
    try {
      final response = await client
          .from('activities')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(15)
          .timeout(const Duration(seconds: 10));

      final activities = (response as List).map((e) => Activity.fromJson(e)).toList();
      debugPrint('[FOREGROUND TASK POLL] Fetched ${activities.length} rows.');

      if (_isFirstLoad) {
        for (final act in activities) {
          _seenActivityIds.add(act.id);
        }
        _isFirstLoad = false;
      } else {
        for (final act in activities) {
          if (!_seenActivityIds.contains(act.id)) {
            _seenActivityIds.add(act.id);
            _triggerActivityAlert(act);
          }
        }
      }
    } catch (e) {
      debugPrint('[FOREGROUND TASK POLL ERROR] $e');
    }
  }

  void _triggerActivityAlert(Activity activity) {
    String title = 'EditFlow Update';
    switch (activity.type) {
      case 'comment_created':
        title = '💬 New Feedback Comment';
        break;
      case 'project_created':
        title = '📁 Project Assigned';
        break;
      case 'payment_overdue':
        title = '⚠️ Payment Overdue';
        break;
      case 'due_date_overdue':
        title = '🚨 Deadline Passed';
        break;
      case 'due_date_12h':
        title = '⏰ Deadline Warning (12h)';
        break;
      case 'due_date_1d':
        title = '⏰ Deadline Warning (24h)';
        break;
      case 'due_date_2d':
        title = '⏰ Deadline Warning (48h)';
        break;
      case 'project_updated':
        title = '✏️ Project Updated';
        break;
      case 'status_changed':
        title = '🔄 Status Changed';
        break;
      case 'payment_received':
        title = '💰 Payment Received';
        break;
      case 'client_created':
        title = '👥 Client Connected';
        break;
    }

    LocalNotificationService.showNotification(
      id: activity.id.hashCode,
      title: title,
      body: activity.description,
      payload: activity.referenceId,
    );
  }
}

// ─── MAIN SERVICE API ───────────────────────────────────────────────
class EditFlowForegroundService {
  static void initialize() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'editflow_foreground_channel',
        channelName: 'EditFlow Background Sync',
        channelDescription: 'Keeps EditFlow workspace synchronized in the background',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(30000), // Trigger stats check every 30 seconds
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> start() async {
    try {
      final isRunning = await FlutterForegroundTask.isRunningService;
      if (isRunning) {
        debugPrint('[FOREGROUND SERVICE] Service already running. Skipping start.');
        return;
      }

      // Check / request notification permission
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        // Request ignoring battery optimization to prevent background sleep (optional, doesn't prompt unless needed)
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }

      final reqPermission = await FlutterForegroundTask.checkNotificationPermission();
      if (reqPermission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }

      debugPrint('[FOREGROUND SERVICE] Starting Service...');
      await FlutterForegroundTask.startService(
        serviceId: 198,
        notificationTitle: 'EditFlow Workspace Dashboard',
        notificationText: 'Active: 0 Projects | Running in background',
        notificationIcon: null, // Uses default android icon (mipmap/ic_launcher)
        callback: startCallback,
      );
      debugPrint('[FOREGROUND SERVICE] Service started.');
    } catch (e) {
      debugPrint('[FOREGROUND SERVICE START ERROR] $e');
    }
  }

  static Future<void> stop() async {
    try {
      final isRunning = await FlutterForegroundTask.isRunningService;
      if (!isRunning) return;

      debugPrint('[FOREGROUND SERVICE] Stopping Service...');
      await FlutterForegroundTask.stopService();
      debugPrint('[FOREGROUND SERVICE] Service stopped.');
    } catch (e) {
      debugPrint('[FOREGROUND SERVICE STOP ERROR] $e');
    }
  }
}
