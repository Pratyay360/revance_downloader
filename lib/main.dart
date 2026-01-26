import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rd_manager/download_page.dart';
import 'package:rd_manager/intro.dart';
import 'package:rd_manager/repo_data.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_logging/sentry_logging.dart';
import 'package:ntfluttery/ntfluttery.dart';
import 'secrets.dart';
import 'dart:async';

Future<void> main() async {
  await SentryFlutter.init((options) {
    options.dsn = sentryDsn;
    options.addIntegration(LoggingIntegration());
    options.sendDefaultPii = true;
    options.tracesSampleRate = 1.0;
    options.enableLogs = true;
    options.debug = true;
  }, appRunner: initApp);
}

void initApp() async {
  AwesomeNotifications().initialize(
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
  runApp(const MyApp());
  startNtfyListener();
}

/// Long-running loop that long-polls the ntfy instance and shows local notifications.
/// - Dedupes by title+message to avoid spamming repeated events.
/// - On error, waits and reports to Sentry.
void startNtfyListener() {
  final client = NtflutteryService(
    credentials: Credentials(username: ntfyUsername, password: ntfyToken),
  );

  String _lastMessageKey = '' ;

  Future<void> _pollLoop() async {
    while (true) {  
      try {
        final latest = await client.getLatestMessage(
          '$instance/$topic/json?poll=1',
        );
        final messageKey = '${latest.title}::${latest.message}';
        if (messageKey != _lastMessageKey) {
          _lastMessageKey = messageKey;

          final allowed = await AwesomeNotifications().isNotificationAllowed();
          if (allowed == true) {
            await AwesomeNotifications().createNotification(
              content: NotificationContent(
                id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
                channelKey: 'basic_channel',
                title: latest.title,
                body: latest.message,
                notificationLayout: NotificationLayout.Default,
              ),
            );
          }
        }
      } catch (e, st) {
        // Simple backoff on errors
        await Future.delayed(const Duration(seconds: 10));
        try {
          await Sentry.captureException(e, stackTrace: st);
        } catch (_) {}
      }
    }
  }

  // fire-and-forget
  _pollLoop();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _buildTheme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: colorScheme.surfaceContainer,
        foregroundColor: colorScheme.onSurface,
      ),
      scaffoldBackgroundColor: colorScheme.surface,
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: colorScheme.surfaceContainer,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.inverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final lightScheme =
            lightDynamic ?? ColorScheme.fromSeed(seedColor: Colors.green);
        final darkScheme =
            darkDynamic ??
            ColorScheme.fromSeed(
              seedColor: ThemeData.dark().colorScheme.primary,
              brightness: ThemeData.dark().brightness,
            );

        return MaterialApp(
          title: 'ReVance Downloader',
          theme: _buildTheme(lightScheme),
          darkTheme: _buildTheme(darkScheme),
          themeMode: ThemeMode.system,
          home: const MyHomePage(title: 'main page :)'),
          navigatorObservers: [SentryNavigatorObserver()],
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Future<Widget> _checkPermissionsAndNavigate() async {
    final bool notificationGranted = await Permission.notification.isGranted;
    final bool storageGranted =
        await Permission.manageExternalStorage.isGranted;
    final bool installGranted =
        await Permission.requestInstallPackages.isGranted;

    if (notificationGranted && storageGranted && installGranted) {
      final repos = await loadRepoDataList();
      if (repos.isNotEmpty) {
        return RepoSelector(repos: repos);
      }
    }
    return const IntroScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _checkPermissionsAndNavigate(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        } else {
          return snapshot.data!;
        }
      },
    );
  }
}

class RepoSelector extends StatefulWidget {
  const RepoSelector({super.key, required this.repos});

  final List<RepoData> repos;

  @override
  State<RepoSelector> createState() => _RepoSelectorState();
}

class _RepoSelectorState extends State<RepoSelector> {
  late int _selectedRepoIndex;

  @override
  void initState() {
    super.initState();
    _selectedRepoIndex = 0;
  }

  @override
  Widget build(BuildContext context) {
    final selectedRepo = widget.repos[_selectedRepoIndex];

    return DownloadPage(
      key: ValueKey(selectedRepo.userName + selectedRepo.repoName),
      userName: selectedRepo.userName,
      repoName: selectedRepo.repoName,
      repos: widget.repos,
      currentIndex: _selectedRepoIndex,
      onRepoChanged: (index) {
        setState(() {
          _selectedRepoIndex = index;
        });
      },
    );
  }
}
