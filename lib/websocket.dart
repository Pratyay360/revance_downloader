import 'package:flutter/foundation.dart';
import 'package:rd_manager/notifications.dart';
import 'package:rd_manager/secrets.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  static WebSocketChannel? _channel;

  static void init() {
    try {
      // connecting to the websocket url from secrets.dart
      _channel = WebSocketChannel.connect(Uri.parse(ntfyHost));

      _channel!.stream.listen(
        (message) {
          // Show notification on message received
          NotificationsService.showNotification(
            id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            title: 'New Message',
            body: message.toString(),
          );
        },
        onError: (error) {
          debugPrint('WebSocket Error: $error');
        },
        onDone: () {
          debugPrint('WebSocket Connection Closed');
        },
      );
    } catch (e) {
      debugPrint('WebSocket Init Error: $e');
    }
  }

  static void dispose() {
    _channel?.sink.close();
  }

  static void sendMessage(String message) {
    _channel?.sink.add(message);
  }
}
