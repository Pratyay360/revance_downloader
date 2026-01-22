import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rd_manager/repo_data.dart';
import 'package:package_installer_plus/package_installer_plus.dart';
import 'package:sn_progress_dialog/sn_progress_dialog.dart';
import 'package:sqflite/sqflite.dart';
import 'package:file_saver/file_saver.dart';
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

  const DownloadPage({
    super.key,
    required this.userName,
    required this.repoName,
  });

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  final Dio _dio = Dio();
  bool _isLoading = true;

  List<GithubAsset> _assets = [];
  String? _errorMessage;
  double _progressValue = 0.0;

  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _cancelToken = CancelToken();
    _dio.options.connectTimeout = Duration.zero;
    _dio.options.receiveTimeout = Duration.zero;
    _fetchReleases();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('Widget disposed');
    super.dispose();
  }

  Future<void> _fetchReleases() async {
    try {
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
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                    color: Theme.of(context).colorScheme.tertiary,
                    onTap: () async {
                      Navigator.pop(context);
                      bool success = await _processDownload(
                        asset,
                        saveToPublic: false,
                      );
                      if (success && mounted) {
                        final db = await _getDatabase();
                        await db.insert(
                          'downloads',
                          {'digest': asset.digest},
                          conflictAlgorithm: ConflictAlgorithm.replace,
                        );
                        debugPrint('Saved digest to DB: ${asset.digest}');
                      }
                    },
                  ),

                  // Option 2: Save & Install (Cache -> Save Public -> Open)
                  _actionButton(
                    icon: Icons.save_alt,
                    label: 'Open in Browser',
                    color: Theme.of(context).colorScheme.secondary,
                    onTap: () async {
                      Navigator.pop(context);

                      final success = Uri.parse(asset.downloadUrl).isAbsolute;
                      if (success && mounted) {
                        final db = await _getDatabase();
                        await db.insert(
                          'downloads',
                          {'digest': asset.digest},
                          conflictAlgorithm: ConflictAlgorithm.replace,
                        );
                        final uri = Uri.parse(asset.downloadUrl);
                        try {
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          } else {
                            if (mounted) {
                              _snack('Could not launch ${asset.downloadUrl}');
                            }
                          }
                        } catch (e) {
                          if (mounted) _snack('Error opening link: $e');
                        }
                        debugPrint('Saved digest to DB: ${asset.digest}');
                      }
                    },
                  ),
                ],
              ),
            ],
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
            ),
          ],
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

  Future<bool> _processDownload(
    GithubAsset asset, {
    required bool saveToPublic,
  }) async {
    // A. Permission check (if saving to public)
    if (saveToPublic) {
      if (await Permission.storage.request().isDenied) {
        if (mounted) _snack('Storage permission denied');
        return false;
      }
    }

    if (!mounted) return false;
    final ProgressDialog pd = ProgressDialog(context: context);
    pd.show(
      max: 100,
      msg: 'Downloading to cache...',
      progressType: ProgressType.determinate,
    );

    try {
      // B. Create a temporary file path
      final Directory tempDir = Directory.systemTemp;
      final String tempPath = '${tempDir.path}/${asset.name}';

      // C. Download logic using Dio
      await _dio.download(
        asset.downloadUrl,
        tempPath,
        cancelToken: _cancelToken,
        onReceiveProgress: (count, total) {
          if (total != -1 && mounted) {
            final value = count / total;
            if (_progressValue != value) {
              setState(() {
                if (_progressValue < 1.0) {
                  _progressValue = value;
                } else {
                  _progressValue = 0.0;
                }
              });
              if (pd.isOpen()) {
                int progress = (value * 100).toInt();
                pd.update(
                  value: progress,
                  msg: '${_formatBytes(count)} / ${_formatBytes(total)}',
                );
              }
              debugPrint('${(_progressValue * 100).toStringAsFixed(0)}%');
            }
          }
        },
      );

      if (!mounted) {
        if (pd.isOpen()) pd.close();
        return false;
      }

      // D. "Save" Step: Copy from Temp to Public Downloads
      if (saveToPublic) {
        if (pd.isOpen()) pd.update(value: 100, msg: 'Saving to device...');

        // Read the temp file
        File tempFile = File(tempPath);
        Uint8List bytes = await tempFile.readAsBytes();

        if (!mounted) {
          if (pd.isOpen()) pd.close();
          return false;
        }

        // Save using FileSaver
        final savedPath = await FileSaver.instance.saveFile(
          name: asset.name,
          bytes: bytes,
          mimeType: MimeType.other,
        );
        _snack('Saved to: $savedPath');
      }

      if (pd.isOpen()) pd.close();

      // E. "Install" Step: Open the file
      if (mounted) {
        await _installApk(tempPath);
      }
      return true;
    } catch (e) {
      if (pd.isOpen()) pd.close();
      if (mounted) {
        // Check if it was a user cancellation to avoid scary errors
        if (CancelToken.isCancel(e as DioException)) {
          debugPrint('Download cancelled');
        } else {
          _snack('Error: $e');
        }
      }
      return false;
    }
  }

  Future<void> _installApk(String filePath) async {
    try {
      final PackageInstallerPlus installer = PackageInstallerPlus();
      final dynamic res = await installer.installApk(filePath: filePath);
      if (!mounted) return;

      if ((res is Map && res['isSuccess'] == true) || res == true) {
        _snack('install apk success');
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

  // ---------------------------------------------------------
  // 6. UI Helpers
  // ---------------------------------------------------------
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
        title: const Text('Releases'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RepoDataList()),
              );
            },
          ),
        ],
      ),
      body: _buildBody(),
      // Quick action: fetch from internet (latest asset) and install
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
