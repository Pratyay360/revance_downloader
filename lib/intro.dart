import 'package:flutter/material.dart';
import 'package:revance_downloader/main.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:revance_downloader/repo_data.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final introKey = GlobalKey<IntroductionScreenState>();

  // Repo data controllers
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _repoController = TextEditingController();

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

    // 3. Save Data
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
        actions: [
          TextButton(
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
      image: Icon(icon, size: 100, color: Colors.blueAccent),
      footer: FutureBuilder<PermissionStatus>(
        future: permission.status,
        builder: (context, snapshot) {
          final isGranted = snapshot.data?.isGranted ?? false;
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: ElevatedButton.icon(
              onPressed: isGranted
                  ? null
                  : () async {
                await permission.request();
                setState(() {}); // Refresh UI
              },
              icon: Icon(isGranted ? Icons.check : icon),
              label: Text(isGranted ? "Allowed" : "Grant Permission"),
              style: ElevatedButton.styleFrom(
                backgroundColor: isGranted ? Colors.green : Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
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
        globalBackgroundColor: Colors.white,
        allowImplicitScrolling: true,
        pages: [
          PageViewModel(
            title: "Welcome",
            body: "Let's set up your ReVanced Downloader.",
            image: const Icon(Icons.download, size: 100, color: Colors.blue),
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
            image: const Icon(Icons.code, size: 75, color: Colors.blue),
            // Use footer to place inputs above the buttons
            footer: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 10.0,
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _userController,
                    decoration: const InputDecoration(
                      labelText: 'User Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10.0)),
                      ),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _repoController,
                    decoration: const InputDecoration(
                      labelText: 'Repo Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10.0)),
                      ),
                      prefixIcon: Icon(Icons.code),
                    ),
                  ),
                ],
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