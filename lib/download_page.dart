import 'dart:async';

import 'package:app_installer/app_installer.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_file_downloader/flutter_file_downloader.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rd_manager/repo_data.dart';
import 'package:sn_progress_dialog/sn_progress_dialog.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';

// ---------------------------------------------------------
// 1. Data Model
// ---------------------------------------------------------
class GithubAsset {
  final int id;
  final String name;
  final String downloadUrl;
  final int size;
  final String digest;

  GithubAsset({
    required this.id,
    required this.name,
    required this.downloadUrl,
    required this.size,
    required this.digest,
  });

  factory GithubAsset.fromJson(Map<String, dynamic> json) {
    return GithubAsset(
      id: json['id'],
      name: json['name'],
      downloadUrl: json['browser_download_url'] ?? '',
      size: json['size'] ?? 0,
      digest: json['digest'] ?? '',
    );
  }
}

// ---------------------------------------------------------
// 2. The Widget
// ---------------------------------------------------------
class DownloadPage extends StatefulWidget {
  final String userName;
  final String repoName;
  final List<RepoData> repos;
  final int currentIndex;
  final Function(int) onRepoChanged;

  const DownloadPage({
    super.key,
    required this.userName,
    required this.repoName,
    required this.repos,
    required this.currentIndex,
    required this.onRepoChanged,
  });

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  final Dio _dio = Dio();
  bool _isLoading = true;

  List<GithubAsset> _assets = [];
  String? _errorMessage;

  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _cancelToken = CancelToken();
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _fetchReleases();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('Widget disposed');
    super.dispose();
  }

  Future<void> _fetchReleases() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final response = await _dio.get(
        'https://api.github.com/repos/${widget.userName}/${widget.repoName}/releases/latest',
        cancelToken: _cancelToken,
      );

      if (response.statusCode == 200) {
        final List<dynamic> assetsJson = response.data['assets'] ?? [];
        if (mounted) {
          setState(() {
            _assets = assetsJson
                .map((e) => GithubAsset.fromJson(e))
                .where(
                  (asset) =>
                      asset.name.toLowerCase().endsWith('.apk') ||
                      asset.name.toLowerCase().endsWith('.aab'),
                )
                .toList();
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to load: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showActionOptions(GithubAsset asset) {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Action for ${asset.name}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose how you want to handle this file.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Option 1: Install Only (Cache -> Open)
                    _actionButton(
                      icon: Icons.system_update,
                      label: 'Download & Install',
                      color: Theme.of(context).colorScheme.primary,
                      onTap: () {
                        Navigator.pop(context);
                        _processDownload(asset, saveToPublic: false);
                      },
                    ),

                    // Option 2: Save & Install (Cache -> Save Public -> Open)
                    _actionButton(
                      icon: Icons.save_alt,
                      label: 'Download & Save',
                      color: Theme.of(context).colorScheme.secondary,
                      onTap: () {
                        Navigator.pop(context);
                        _processDownload(asset, saveToPublic: true);
                      },
                    ),

                    // Option 3: Open in Browser
                    _actionButton(
                      icon: Icons.open_in_browser,
                      label: 'Open in Browser',
                      color: Theme.of(context).colorScheme.tertiary,
                      onTap: () async {
                        Navigator.pop(context);
                        final uri = Uri.parse(asset.downloadUrl);
                        try {
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        } catch (e) {
                          _snack('Error opening link: $e');
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // 5. Core Logic: Download -> Cache -> (Save) -> Install
  // ---------------------------------------------------------
  Future<Database> _getDatabase() async {
    return openDatabase(
      'downloads.db',
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE downloads(id INTEGER PRIMARY KEY, name TEXT, digest TEXT, path TEXT)',
        );
      },
      version: 1,
    );
  }

  Future<void> _processDownload(
    GithubAsset asset, {
    required bool saveToPublic,
  }) async {
    // A. Permission check (if saving to public)
    if (saveToPublic) {
      if (await Permission.storage.request().isDenied) {
        if (mounted) _snack('Storage permission denied');
        return;
      }
    }

    if (!mounted) return;
    final ProgressDialog pd = ProgressDialog(context: context);

    FileDownloader.downloadFile(
      url: asset.downloadUrl,
      name: asset.name,
      downloadDestination: saveToPublic
          ? DownloadDestinations.publicDownloads
          : DownloadDestinations.appFiles,
      onProgress: (fileName, progress) {
        if (mounted) {
          final value = progress.toInt();
          if (!pd.isOpen()) {
            pd.show(
              max: 100,
              msg: 'Downloading ${asset.name}',
              progressType: ProgressType.determinate,
            );
          }
          pd.update(value: value, msg: 'Downloading... $value%');
        }
      },
      onDownloadCompleted: (path) async {
        if (pd.isOpen()) pd.close();
        if (mounted) {
          _snack(
            'Download completed. File saved to: ${saveToPublic ? "Downloads" : "App Files"}',
          );
          final db = await _getDatabase();
          await db.insert('downloads', {
            'digest': asset.digest,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          debugPrint('Saved digest to DB: ${asset.digest}');
          await _installApk(path);
        }
      },
      onDownloadError: (error) {
        if (pd.isOpen()) pd.close();
        if (mounted) {
          _snack('Download Error: $error');
        }
      },
    );
  }

  Future<void> _installApk(String filePath) async {
    try {
      final dynamic res = AppInstaller.installApk(filePath);
      if (!mounted) return;

      if ((res is Map && res['isSuccess'] == true) || res == true) {
        _snack('Install apk success');
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: 2,
            channelKey: 'basic_channel',
            title: 'Installation Complete',
            body: 'APK installed successfully',
          ),
        );
      } else {
        final String err = (res is Map)
            ? (res['errorMessage']?.toString() ?? res.toString())
            : res.toString();
        _snack('install apk fail: $err');
      }
    } catch (e) {
      if (!mounted) return;
      _snack('Install failed: $e');
    }
  }

  Future<void> _quickInstallLatestApk() async {
    if (_assets.isEmpty) {
      _snack('No releases found yet. Pull to refresh.');
      return;
    }
    final GithubAsset asset = _assets.firstWhere(
      (a) => a.name.toLowerCase().endsWith('.apk'),
      orElse: () => _assets.first,
    );
    await _processDownload(asset, saveToPublic: false);
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  String _formatBytes(int bytes) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.userName}/${widget.repoName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RepoDataList()),
              ).then((_) {
                // Refresh when returning from settings
                _fetchReleases();
              });
            },
          ),
        ],
      ),
      drawer: widget.repos.length > 1
          ? Drawer(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    child: const Text(
                      'Repositories',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...List.generate(widget.repos.length, (index) {
                    final repo = widget.repos[index];
                    return ListTile(
                      leading: Icon(
                        Icons.code,
                        color: widget.currentIndex == index
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      title: Text(
                        repo.repoName,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      subtitle: Text(
                        repo.userName,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      selected: widget.currentIndex == index,
                      onTap: () {
                        Navigator.pop(context);
                        if (widget.currentIndex != index) {
                          widget.onRepoChanged(index);
                        }
                      },
                    );
                  }),
                ],
              ),
            )
          : null,
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.download),
        label: const Text('Download & Install'),
        onPressed: _quickInstallLatestApk,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _fetchReleases,
      child: _errorMessage != null || _assets.isEmpty
          ? LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: constraints.maxHeight,
                    child: Center(
                      child: Text(_errorMessage ?? 'No assets found.'),
                    ),
                  ),
                );
              },
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _assets.length,
              itemBuilder: (context, index) {
                final asset = _assets[index];

                return Card(
                  key: ValueKey(asset.id),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  elevation: 1,
                  child: InkWell(
                    onTap: () => _showActionOptions(asset),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ListTile(
                        leading: Icon(
                          Icons.extension,
                          size: 32,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        title: Text(
                          asset.name,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        subtitle: Text(
                          _formatBytes(asset.size),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
