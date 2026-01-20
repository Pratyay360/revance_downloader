import 'package:flutter/material.dart';
import 'package:revance_downloader/intro.dart';
import 'package:revance_downloader/download_page.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:revance_downloader/repo_data.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          theme: ThemeData(
            colorScheme:
            lightDynamic ?? ColorScheme.fromSeed(seedColor: Colors.green),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme:
            darkDynamic ??
                ColorScheme.fromSeed(
                  seedColor: Colors.deepPurple,
                  brightness: Brightness.dark,
                ),
          ),
          themeMode: ThemeMode.system,
          home: const MyHomePage(title: 'main page :)'),
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

  Future<Widget> _checkPermissionsAndNavigate() async {
    final bool notificationGranted = await Permission.notification.isGranted;
    final bool storageGranted =
    await Permission.manageExternalStorage.isGranted;
    final bool installGranted =
    await Permission.requestInstallPackages.isGranted;

    if (notificationGranted && storageGranted && installGranted) {
      final repos = await loadRepoDataList();
      if (repos.isNotEmpty) {
        return DownloadPage(
          userName: repos.first.userName,
          repoName: repos.first.repoName,
        );
      }
    }
    return const IntroScreen();
  }
}