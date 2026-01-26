import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';

class NotificationHelper {
  static Future<void> init() async {
    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelGroupKey: 'basic_channel_group',
          channelKey: 'basic_channel',
          channelName: 'Basic notifications',
          channelDescription: 'Notification channel for basic tests',
          defaultColor: const Color(0xFF9D50DD),
          ledColor: Colors.white,
          importance: NotificationImportance.High,
        ),
        NotificationChannel(
          channelGroupKey: 'progress_channel_group',
          channelKey: 'progress_channel',
          channelName: 'Progress notifications',
          channelDescription: 'Notification channel for download progress',
          defaultColor: const Color(0xFF9D50DD),
          ledColor: Colors.white,
          importance: NotificationImportance.High,
          enableVibration: false,
        ),
      ],
      channelGroups: [
        NotificationChannelGroup(
          channelGroupKey: 'basic_channel_group',
          channelGroupName: 'Basic',
        ),
        NotificationChannelGroup(
          channelGroupKey: 'progress_channel_group',
          channelGroupName: 'Progress',
        ),
      ],
    );
  }

  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    final allowed = await AwesomeNotifications().isNotificationAllowed();
    if (allowed) {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          channelKey: 'basic_channel',
          title: title,
          body: body,
          notificationLayout: NotificationLayout.Default,
        ),
      );
    }
  }
}
