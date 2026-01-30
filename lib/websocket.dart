import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:rd_manager/secrets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  static WebSocketChannel? _channel;

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Call once in main()
  static Future<void> initNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const settings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(settings: settings);
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'websocket_channel',
      'WebSocket Messages',
      channelDescription: 'Notifications from WebSocket events',
      importance: Importance.max,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  static void init() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(ntfyHost));

      _channel!.stream.listen(
        (rawMessage) {
          try {
            // Expecting JSON from server
            final data = jsonDecode(rawMessage as String);

            showNotification(
              id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              title: data['title']?.toString() ?? 'Message',
              body: data['body']?.toString() ?? rawMessage.toString(),
            );
          } catch (e, stack) {
            Sentry.captureException(e, stackTrace: stack);
          }
        },
        onError: (error, stack) {
          Sentry.captureException(error, stackTrace: stack);
        },
      );
    } catch (e, stack) {
      Sentry.captureException(e, stackTrace: stack);
    }
  }

  static void sendMessage(String message) {
    _channel?.sink.add(message);
  }

  static void dispose() {
    _channel?.sink.close();
    _channel = null;
  }
}
