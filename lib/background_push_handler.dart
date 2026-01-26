import 'package:unifiedpush/unifiedpush.dart';
import 'package:rd_manager/notification_helper.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Background message handler for UnifiedPush
/// This function handles push messages when the app is in the background
void handleBackgroundMessage(PushMessage message, String instance) {
  // Process the push message in the background
  try {
    String messageContent = String.fromCharCodes(message.content);

    // Show a notification even when the app is in the background
    NotificationHelper.showNotification(
      title: 'ReVance Update',
      body: messageContent,
    );
  } catch (e) {
    // Log the error but don't crash the background process
    Sentry.captureMessage('Error handling background push message: $e');
  }
}

/// Background endpoint handler
/// Called when a new endpoint is registered
void handleBackgroundEndpoint(PushEndpoint endpoint, String instance) {
  Sentry.captureMessage('Background: New endpoint: ${endpoint.url} for instance: $instance');
  // In a real app, you might want to send this endpoint to your server
}

/// Background registration failure handler
void handleBackgroundRegistrationFailure(FailedReason reason, String instance) {
  Sentry.captureMessage('Background: Registration failed: $reason for instance: $instance');
}

/// Background unregistration handler
void handleBackgroundUnregister(String instance) {
  Sentry.captureMessage('Background: Unregistered instance: $instance');
}
