import 'dart:convert';
import 'package:rd_manager/notifications.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'secrets.dart';

class WebSocketService {
  static WebSocketChannel? _channel;

  static void init() {
    try {
      // connecting to the websocket url from secrets.dart
      _channel = WebSocketChannel.connect(Uri.parse(ntfyHost));

      _channel!.stream.listen(
        (message) {
          if (message.contains('sequence_id')) {
            try {
              final Map<String, dynamic> jsonMessage = json.decode(message);
              final String? messageContent = jsonMessage['message'] as String?;
              final String title =
                  jsonMessage['title'] as String? ?? 'New Message';
              if (messageContent != null) {
                NotificationsService.showNotification(
                  id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  title: title,
                  body: messageContent,
                );
              }
            } catch (e) {
              Sentry.captureException('Failed to parse WebSocket message: $e');
            }
          }
        },
        onError: (error) {
          Sentry.captureException('WebSocket Error: $error');
        },
        onDone: () {
          Sentry.captureMessage('WebSocket Connection Closed');
        },
      );
    } catch (e) {
      Sentry.captureException(e);
    }
  }

  static void dispose() {
    _channel?.sink.close();
  }

  static void sendMessage(String message) {
    _channel?.sink.add(message);
  }
}
