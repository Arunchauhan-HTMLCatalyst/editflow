import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'local_notification_service.dart';
import 'supabase_service.dart';

class FcmService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    try {
      // 1. Register foreground message listener to trigger local notification banners
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCM] Foreground notification received: ${message.notification?.title}');
        final notification = message.notification;
        if (notification != null) {
          LocalNotificationService.showNotification(
            id: notification.hashCode,
            title: notification.title ?? 'EditFlow Update',
            body: notification.body ?? '',
            payload: message.data.containsKey('route') ? message.data['route'] : null,
          );
        }
      });

      // 2. Handle token updates on refresh
      _fcm.onTokenRefresh.listen((token) {
        debugPrint('[FCM] Token refreshed: $token');
        _updateTokenInDatabase(token);
      });
    } catch (e, st) {
      debugPrint('[FCM] FCM initialization failed: $e\n$st');
    }
  }

  static Future<void> requestPermissionAndInitialize() async {
    try {
      debugPrint('[FCM] Requesting notification permissions after splash...');
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

      // Capture the initial FCM token for the device
      final token = await _fcm.getToken();
      if (token != null) {
        debugPrint('[FCM] Initial token acquired: $token');
        await _updateTokenInDatabase(token);
      }
    } catch (e, st) {
      debugPrint('[FCM] Permission request failed: $e\n$st');
    }
  }

  static Future<void> updateTokenForCurrentUser() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await _updateTokenInDatabase(token);
      }
    } catch (e) {
      debugPrint('[FCM] Failed to update token on login: $e');
    }
  }

  static Future<void> _updateTokenInDatabase(String token) async {
    try {
      final user = SupabaseService.instance.auth.currentUser;
      if (user != null) {
        await SupabaseService.instance
            .from('profiles')
            .update({'fcm_token': token})
            .eq('id', user.id);
        debugPrint('[FCM] Synced token to database profile: ${user.id}');
      }
    } catch (e) {
      debugPrint('[FCM] Failed to save token to profile: $e');
    }
  }
}
