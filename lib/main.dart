import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rd_manager/download_page.dart';
import 'package:rd_manager/intro.dart';
import 'package:rd_manager/repo_data.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_logging/sentry_logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rd_manager/websocket.dart';
import 'package:rd_manager/notifications.dart';
import 'secrets.dart';
import 'dart:async';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  globalArgs = args;

  await SentryFlutter.init((options) {
    options.dsn = sentryDsn;
    options.addIntegration(LoggingIntegration());
    options.sendDefaultPii = true;
    options.tracesSampleRate = 1.0;
    options.enableLogs = true;
    options.debug = false;
  }, appRunner: initApp);
}

List<String> globalArgs = <String>[];
void initApp() async {
  WebSocketService.init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    await NotificationsService.initialize();
  }

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
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
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
    final prefs = await SharedPreferences.getInstance();
    final bool introCompleted = prefs.getBool('intro_completed') ?? false;

    final bool notificationGranted = await Permission.notification.isGranted;
    final bool storageGranted =
        await Permission.manageExternalStorage.isGranted;
    final bool installGranted =
        await Permission.requestInstallPackages.isGranted;

    if (notificationGranted && storageGranted && installGranted) {
      if (introCompleted) {
        final repos = await loadRepoDataList();
        if (repos.isNotEmpty) {
          return RepoSelector(repos: repos);
        } else {
          // If intro is completed but no repos exist, show repo management
          return const RepoDataList();
        }
      } else {
        // Show intro if not completed
        return const IntroScreen();
      }
    }
    // If permissions not granted, show intro to get permissions
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
    // Default to "All Apps" (-1)
    _selectedRepoIndex = -1;
  }

  void _handleRepoChange(int index) {
    setState(() {
      _selectedRepoIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // If index is -1, show All Apps
    if (_selectedRepoIndex == -1) {
      return AllAppsView(repos: widget.repos, onRepoChanged: _handleRepoChange);
    }

    // Otherwise show specific repo
    final selectedRepo = widget.repos[_selectedRepoIndex];

    return DownloadPage(
      key: ValueKey(selectedRepo.userName + selectedRepo.repoName),
      userName: selectedRepo.userName,
      repoName: selectedRepo.repoName,
      repos: widget.repos,
      currentIndex: _selectedRepoIndex,
      onRepoChanged: _handleRepoChange,
    );
  }
}
