import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rd_manager/main.dart';
import 'package:rd_manager/repo_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rd_manager/secrets.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final introKey = GlobalKey<IntroductionScreenState>();

  // Repo data controllers
  final TextEditingController _userController = TextEditingController(
    text: user_name,
  );
  final TextEditingController _repoController = TextEditingController(
    text: repo_name,
  );

  // List of permissions
  final List<Permission> _requiredPermissions = [
    Permission.manageExternalStorage,
    Permission.requestInstallPackages,
    Permission.notification,
  ];

  @override
  void dispose() {
    _userController.dispose();
    _repoController.dispose();
    super.dispose();
  }

  Future<void> _onIntroEnd(BuildContext context) async {
    // 1. Validate Inputs
    if (_userController.text.trim().isEmpty ||
        _repoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both User Name and Repo Name'),
        ),
      );
      return; // Stop execution
    }

    // 2. Validate Permissions
    List<String> missingPermissions = [];
    for (var permission in _requiredPermissions) {
      if (!(await permission.isGranted)) {
        String name = permission.toString().split('.').last;
        missingPermissions.add(name);
      }
    }

    if (missingPermissions.isNotEmpty) {
      if (context.mounted) _showPermissionAlert(context, missingPermissions);
      return; // Stop execution if permissions missing
    }

    final repo = RepoData(
      userName: _userController.text.trim(),
      repoName: _repoController.text.trim(),
    );

    // Save this as the initial list of repos
    await saveRepoDataList([repo]);
    // 4. Mark Intro Complete and Navigate
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('intro_completed', true);

    if (context.mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const MyApp()));
    }
  }

  void _showPermissionAlert(BuildContext context, List<String> missing) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Permissions Required"),
        content: Text(
          "The following permissions are mandatory:\n\n• ${missing.join('\n• ')}",
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  PageViewModel _buildPermissionPage({
    required String title,
    required String body,
    required IconData icon,
    required Permission permission,
  }) {
    return PageViewModel(
      title: title,
      body: body,
      image: Builder(
        builder: (context) =>
            Icon(icon, size: 100, color: Theme.of(context).colorScheme.primary),
      ),
      footer: FutureBuilder<PermissionStatus>(
        future: permission.status,
        builder: (context, snapshot) {
          final isGranted = snapshot.data?.isGranted ?? false;
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: FilledButton.icon(
              onPressed: isGranted
                  ? null
                  : () async {
                      await permission.request();
                      setState(() {}); // Refresh UI
                    },
              icon: Icon(isGranted ? Icons.check : icon),
              label: Text(isGranted ? "Allowed" : "Grant Permission"),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IntroductionScreen(
        key: introKey,
        globalBackgroundColor: Theme.of(context).colorScheme.surface,
        allowImplicitScrolling: true,
        pages: [
          PageViewModel(
            title: "Welcome",
            body: "Download and manage ReVanced apps easily.",
            image: Builder(
              builder: (context) => Icon(
                Icons.download,
                size: 100,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          _buildPermissionPage(
            title: "Notifications",
            body: "Required to show download progress and completion.",
            icon: Icons.notifications,
            permission: Permission.notification,
          ),
          _buildPermissionPage(
            title: "File Access",
            body: "Required to save APKs to your device.",
            icon: Icons.folder,
            permission: Permission.manageExternalStorage,
          ),
          _buildPermissionPage(
            title: "Install Apps",
            body: "Required to install the downloaded ReVanced apps.",
            icon: Icons.android,
            permission: Permission.requestInstallPackages,
          ),
          // The Input Page
          PageViewModel(
            title: "Repository Details",
            body: "Enter the default GitHub repository details for patches.",
            image: Builder(
              builder: (context) => Icon(
                Icons.code,
                size: 75,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            // Use footer to place inputs above the buttons
            footer: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 10.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _userController,
                      decoration: InputDecoration(
                        labelText: 'User Name',
                        prefixIcon: const Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _repoController,
                      decoration: InputDecoration(
                        labelText: 'Repo Name',
                        prefixIcon: const Icon(Icons.code),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        onDone: () => _onIntroEnd(context),
        showSkipButton: false,
        showBackButton: true,
        back: const Icon(Icons.arrow_back),
        next: const Icon(Icons.arrow_forward),
        done: const Text("Done", style: TextStyle(fontWeight: FontWeight.w600)),
        dotsDecorator: const DotsDecorator(
          size: Size(10.0, 10.0),
          activeSize: Size(22.0, 10.0),
          activeShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(25.0)),
          ),
        ),
      ),
    );
  }
}
