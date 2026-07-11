import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    debugPrint('[LOCAL NOTIFICATION SERVICE] Initializing...');
    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('[LOCAL NOTIFICATION RESPONSE] payload: ${response.payload}');
        },
      );
      debugPrint('[LOCAL NOTIFICATION SERVICE] Initialization completed.');
    } catch (e, st) {
      debugPrint('[LOCAL NOTIFICATION SERVICE] Initialization failed: $e\n$st');
    }
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'editflow_channel',
        'EditFlow Notifications',
        channelDescription: 'Notifications for project updates and comments',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
      );

      const DarwinNotificationDetails iosDetails =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
      debugPrint('[LOCAL NOTIFICATION SERVICE] Shown notification id=$id');
    } catch (e, st) {
      debugPrint('[LOCAL NOTIFICATION SERVICE] Show failed: $e\n$st');
    }
  }
}
