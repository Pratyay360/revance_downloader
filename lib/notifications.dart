import 'dart:developer';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationsService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    try {
      const AndroidInitializationSettings androidInit =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      final InitializationSettings initSettings = InitializationSettings(
        android: androidInit,
      );

      await _plugin.initialize(settings: initSettings);
      _initialized = true;
    } catch (e) {
      log('Error initializing notifications: $e');
    }
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await init();

    // Skip notification if initialization failed
    if (!_initialized) {
      log('Notifications not initialized, skipping notification');
      return;
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'basic_channel',
          'Basic Notifications',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          playSound: true,
        );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  static Future<void> register() async {
    await init();

    // Skip registration if initialization failed
    if (!_initialized) {
      log('Notifications not initialized, skipping registration');
      return;
    }
  }
}
