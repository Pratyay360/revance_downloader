import 'package:rd_manager/notifications.dart';
import 'package:rd_manager/secrets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  static WebSocketChannel? _channel;

  static void init() {
    try {
      // connecting to the websocket url from secrets.dart
      _channel = WebSocketChannel.connect(Uri.parse(ntfyHost));

      _channel!.stream.listen(
        (message) {
          if (message.event.toString() != 'open') {
            NotificationsService.showNotification(
              id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              title: message.event.toString(),
              body: message.message.toString(),
            );
          }
        },
        onError: (error) {
          Sentry.captureException(error);
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
