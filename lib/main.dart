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
import 'package:rd_manager/secrets.dart';
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Proper Material 3 theme construction with dynamic colors
  ThemeData _buildTheme(ColorScheme colorScheme) {
    final bool isDark = colorScheme.brightness == Brightness.dark;

    final textTheme = isDark
        ? Typography.material2021(platform: TargetPlatform.android).white
        : Typography.material2021(platform: TargetPlatform.android).black;

    final surfaceTint = colorScheme.primary;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      brightness: colorScheme.brightness,

      // Surface configurations - Material 3 uses surfaceContainer variants
      scaffoldBackgroundColor: colorScheme.surface,
      canvasColor: colorScheme.surfaceContainerLow,

      // App Bar - Material 3 style
      appBarTheme: AppBarTheme(
        elevation: 0, // M3 uses surface tint, not elevation shadow
        scrolledUnderElevation: 3,
        centerTitle: true,
        backgroundColor: colorScheme.surfaceContainer,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: surfaceTint,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Cards - Material 3 elevated style
      cardTheme: CardThemeData(
        elevation: 0, // M3 uses filled/elevated/outlined variants
        color: colorScheme.surfaceContainerLowest,
        surfaceTintColor: surfaceTint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), // M3 large shape
        ),
      ),

      // Navigation Bar - Standard M3 bottom nav
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        surfaceTintColor: surfaceTint,
        indicatorColor: colorScheme.secondaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelMedium?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            );
          }
          return textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.onSecondaryContainer);
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant);
        }),
      ),

      // Navigation Rail (for tablets/desktop)
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        useIndicator: true,
        indicatorColor: colorScheme.secondaryContainer,
        selectedIconTheme: IconThemeData(
          color: colorScheme.onSecondaryContainer,
        ),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),

      // Buttons - Material 3 shapes (full rounding for filled, 8dp for text)
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 1,
          surfaceTintColor: surfaceTint,
          backgroundColor: colorScheme.surfaceContainerLow,
          foregroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: colorScheme.outline, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          foregroundColor: colorScheme.primary,
        ),
      ),

      // Input decorations - Material 3 outlined style
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        labelStyle: textTheme.bodyLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),

      // Chips - Material 3 assist/suggestion chips
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedColor: colorScheme.secondaryContainer,
        labelStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
      ),

      // FAB - Large FAB style (M3)
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Progress indicators - M3 linear style
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.primaryContainer,
        circularTrackColor: colorScheme.primaryContainer,
      ),

      // SnackBar - M3 style floating
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        insetPadding: const EdgeInsets.all(16),
      ),

      // Dialogs - M3 centered/dialogue style
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: surfaceTint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: textTheme.headlineSmall?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),

      // Bottom sheets
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: surfaceTint,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),

      // Dividers
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
      ),

      // Switches - M3 thumb/track style
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return null;
          return colorScheme.outline;
        }),
      ),

      // Radio/Checkboxes with M3 styling
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(colorScheme.onPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.onSurfaceVariant;
        }),
      ),

      // List tiles
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // Toggles
      toggleButtonsTheme: ToggleButtonsThemeData(
        borderRadius: BorderRadius.circular(8),
        selectedColor: colorScheme.onPrimary,
        fillColor: colorScheme.primary,
        color: colorScheme.onSurface,
      ),

      // Page transitions - Material 3 shared axis/fade through
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        // Fallback schemes if dynamic color unavailable
        final lightFallback = ColorScheme.fromSeed(
          seedColor: const Color(0xFF386A20), // Green seed
          brightness: Brightness.light,
        );

        final darkFallback = ColorScheme.fromSeed(
          seedColor: const Color(0xFF386A20),
          brightness: Brightness.dark,
        );

        final lightScheme = lightDynamic ?? lightFallback;
        final darkScheme = darkDynamic ?? darkFallback;

        return MaterialApp(
          title: 'ReVance Downloader',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(lightScheme),
          darkTheme: _buildTheme(darkScheme),
          themeMode: ThemeMode.system,
          home: const AppEntryPoint(),
          navigatorObservers: [SentryNavigatorObserver()],
          scrollBehavior: MaterialScrollBehavior().copyWith(
            physics: const ClampingScrollPhysics(),
          ),
        );
      },
    );
  }
}

// Renamed from MyHomePage for clarity - handles authentication/routing
class AppEntryPoint extends StatefulWidget {
  const AppEntryPoint({super.key});

  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint> {
  Future<Widget> _initializeApp() async {
    final prefs = await SharedPreferences.getInstance();
    final bool introCompleted = prefs.getBool('intro_completed') ?? false;

    // Check permissions
    final bool notificationGranted = await Permission.notification.isGranted;
    final bool storageGranted =
        await Permission.manageExternalStorage.isGranted;
    final bool installGranted =
        await Permission.requestInstallPackages.isGranted;

    final bool allPermissionsGranted =
        notificationGranted && storageGranted && installGranted;

    if (!allPermissionsGranted) {
      return const IntroScreen();
    }

    if (!introCompleted) {
      return const IntroScreen();
    }

    final repos = await loadRepoDataList();

    if (repos.isEmpty) {
      return const RepoDataList(); // Management screen
    }

    return RepoSelector(repos: repos);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _initializeApp(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading...',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Initialization Error',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return snapshot.data ?? const IntroScreen();
      },
    );
  }
}

// Main navigation scaffold with M3 NavigationBar
class MainScaffold extends StatelessWidget {
  final Widget body;
  final int selectedIndex;
  final Function(int) onDestinationSelected;
  final List<NavigationDestination> destinations;
  final String? title;
  final List<Widget>? actions;

  const MainScaffold({
    super.key,
    required this.body,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.title,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    // Use NavigationRail for larger screens, NavigationBar for mobile
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          // Tablet/Desktop layout with NavigationRail
          return Scaffold(
            appBar: title != null
                ? AppBar(title: Text(title!), actions: actions)
                : null,
            body: Row(
              children: [
                NavigationRail(
                  extended: constraints.maxWidth >= 800,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  destinations: destinations
                      .map(
                        (dest) => NavigationRailDestination(
                          icon: dest.icon,
                          selectedIcon: dest.selectedIcon,
                          label: Text(dest.label),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }

        // Mobile layout with NavigationBar
        return Scaffold(
          appBar: title != null
              ? AppBar(title: Text(title!), actions: actions)
              : null,
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            destinations: destinations,
          ),
        );
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
  late int _selectedIndex;
  late final List<NavigationDestination> _destinations;

  @override
  void initState() {
    super.initState();
    _selectedIndex = 0; // Start with "All" or first repo

    // Build destinations: All Apps + each repo
    _destinations = [
      const NavigationDestination(
        icon: Icon(Icons.apps_outlined),
        selectedIcon: Icon(Icons.apps),
        label: 'All',
      ),
      ...widget.repos.map(
        (repo) => NavigationDestination(
          icon: const Icon(Icons.folder_outlined),
          selectedIcon: const Icon(Icons.folder),
          label: repo.repoName,
        ),
      ),
    ];
  }

  void _handleDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_selectedIndex == 0) {
      // Show aggregated view of all repos
      body = AllAppsView(
        repos: widget.repos,
        onRepoChanged: (index) {
          // Adjust for "All" tab being index 0
          if (index >= 0) {
            _handleDestinationSelected(index + 1);
          }
        },
      );
    } else {
      final selectedRepo = widget.repos[_selectedIndex - 1];
      body = DownloadPage(
        key: ValueKey('${selectedRepo.userName}/${selectedRepo.repoName}'),
        userName: selectedRepo.userName,
        repoName: selectedRepo.repoName,
        repos: widget.repos,
        currentIndex: _selectedIndex - 1,
        onRepoChanged: (index) => _handleDestinationSelected(index + 1),
      );
    }

    return MainScaffold(
      title: 'ReVance Manager',
      selectedIndex: _selectedIndex,
      onDestinationSelected: _handleDestinationSelected,
      destinations: _destinations,
      body: body,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () {
            // Navigate to settings
          },
        ),
      ],
    );
  }
}
