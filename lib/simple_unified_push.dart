import 'package:rd_manager/notification_helper.dart';
import 'package:unifiedpush/unifiedpush.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class SimpleUnifiedPush {
  static const String instance = "revance_downloader";

  void init() async {
    // Initialize UnifiedPush with callback functions for receiving notifications
    await UnifiedPush.initialize(
      onMessage: _onMessage,
      onNewEndpoint: _onNewEndpoint,
      onRegistrationFailed: _onRegistrationFailed,
      onUnregistered: _onUnregistered,
    );

    // Try to register with the default distributor
    bool success = await UnifiedPush.tryUseCurrentOrDefaultDistributor();
    if (success) {
      await UnifiedPush.register(instance: instance);
    } else {
      // If no default distributor, try to get any available distributor
      final distributors = await UnifiedPush.getDistributors();
      if (distributors.isNotEmpty) {
        await UnifiedPush.saveDistributor(distributors.first);
        await UnifiedPush.register(instance: instance);
      } else {
        Sentry.captureMessage(
          'No push distributors available. Install a UnifiedPush-compatible app.',
        );
      }
    }
  }

  void _onNewEndpoint(PushEndpoint endpoint, String instance) {
    Sentry.captureMessage('Push endpoint registered: ${endpoint.url}');
  }

  void _onRegistrationFailed(FailedReason reason, String instance) {
    Sentry.captureMessage('Push registration failed: $reason');
  }

  void _onUnregistered(String instance) {
    Sentry.captureMessage('Push unregistered');
  }

  void _onMessage(PushMessage message, String instance) {
    Sentry.captureMessage('Push message received');
    try {
      String messageContent = String.fromCharCodes(message.content);
      Sentry.captureMessage('Push content: $messageContent');

      // Show notification with the received message
      NotificationHelper.showNotification(
        title: 'ReVance Update',
        body: messageContent,
      );
    } catch (e) {
      Sentry.captureMessage('Error processing push message: $e');
    }
  }
}
