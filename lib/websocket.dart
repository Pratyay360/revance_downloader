import 'dart:convert';
import 'dart:developer';
import 'package:rd_manager/notifications.dart';
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
              log('Failed to parse WebSocket message: $e');
            }
          }
        },
        onError: (error) {
          log('WebSocket Error: $error');
        },
        onDone: () {
          log('WebSocket Connection Closed');
        },
      );
    } catch (e) {
      log('WebSocket Initialization Error: $e');
    }
  }

  static void dispose() {
    _channel?.sink.close();
  }

  static void sendMessage(String message) {
    _channel?.sink.add(message);
  }
}
