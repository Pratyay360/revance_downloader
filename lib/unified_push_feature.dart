import 'package:flutter/material.dart';
import 'package:rd_manager/notification_helper.dart';
import 'package:rd_manager/secrets.dart';
import 'package:unifiedpush/unifiedpush.dart';

class UnifiedPushFeature {
  static const String dbusName = "org.example.app";
  
  void init(List<String> args) async {
    // Initialize UnifiedPush with callback functions
    UnifiedPush.initialize(
      onNewEndpoint: onNewEndpoint,
      onRegistrationFailed: onRegistrationFailed,
      onUnregistered: onUnregistered,
      onMessage: onMessage,
    ).then((_) {
        // Register the app with the default or current distributor
        UnifiedPush.tryUseCurrentOrDefaultDistributor().then((success) {
          debugPrint("Current or Default found=$success");
          if (success) {
            UnifiedPush.register(instance: instance);
          } else {
            getUserChoice();
          }
        });
    });
  }

  void onNewEndpoint(PushEndpoint endpoint, String instance) {
    debugPrint('New endpoint: ${endpoint.url} for instance: $instance');
  }

  void onRegistrationFailed(FailedReason reason, String instance) {
    debugPrint('Registration failed: $reason for instance: $instance');
  }

  void onUnregistered(String instance) {
    debugPrint('Unregistered instance: $instance');
  }

  // Callback function when a new push message is received
  void onMessage(PushMessage message, String instance) {
    debugPrint('New push message received: ${message.content}');
    // Handle the push message
    // Convert bytes to string and process the notification
    String messageContent = String.fromCharCodes(message.content);
    debugPrint('Message content: $messageContent');

    NotificationHelper.showNotification(
      title: 'ReVance Update',
      body: messageContent,
    );
  }

  // Function to let user choose a push distributor
  void getUserChoice() async {
    // Get a list of available distributors
    final distributors = await UnifiedPush.getDistributors();

    // For now, we'll just pick the first available distributor
    // In a real implementation, you would show a dialog to let the user choose
    if (distributors.isNotEmpty) {
      final distributor = distributors.first;

      // Save the selected distributor
      await UnifiedPush.saveDistributor(distributor);

      // Register your app with the selected distributor
      UnifiedPush.register(instance: instance);
    } else {
      debugPrint('No distributors available');
      // Handle case where no distributors are available
    }
  }
}
