import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:rd_manager/download_coordinator.dart';
import 'package:rd_manager/repo_data.dart';
import 'package:rd_manager/app_meta.dart';
import 'package:url_launcher/url_launcher.dart';

class GithubAsset {
  final int id;
  String? imageLink;
  final String name;
  final String downloadUrl;
  final int size;
  final String digest;

  GithubAsset({
    required this.id,
    required this.name,
    this.imageLink,
    required this.downloadUrl,
    required this.size,
    required this.digest,
  });

  factory GithubAsset.fromJson(Map<String, dynamic> json) {
    return GithubAsset(
      id: json['id'],
      name: json['name'],
      imageLink: json['image_link'],
      downloadUrl: json['browser_download_url'],
      size: json['size'],
      digest: json['digest'] ?? '',
    );
  }
}

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
  final DownloadCoordinator _downloadCoordinator = DownloadCoordinator();
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
    _downloadCoordinator.dispose();
    super.dispose();
  }

  Future<void> _fetchReleases() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      var response = await _dio.get(
        'https://api.github.com/repos/${widget.userName}/${widget.repoName}/releases/latest',
        cancelToken: _cancelToken,
      );
      final List<dynamic> assetsJson = response.data['assets'] ?? [];
      if (mounted) {
        setState(() {
          _assets = assetsJson.map((e) => GithubAsset.fromJson(e)).where((
            asset,
          ) {
            final name = asset.name.toLowerCase();
            return (name.endsWith('.apk') || name.endsWith('.aab')) &&
                (name.contains('arm64') ||
                    name.contains('universal') ||
                    name.contains('v8a'));
          }).toList();
          _isLoading = false;
        });

        // Proactively fetch metadata/icons for assets
        _fetchMetadataForAssets();
      }
    } on DioException catch (e) {
      log(e.toString());
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.sendTimeout) {
            _errorMessage = 'Connection timed out. Please check your internet.';
          } else {
            _errorMessage = 'Failed to fetch releases: ${e.message}';
          }
        });
      }
    } catch (e) {
      log(e.toString());
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'An unexpected error occurred.';
        });
      }
    }
  }

  Future<void> _fetchMetadataForAssets() async {
    for (var asset in _assets) {
      if (asset.imageLink != null) continue;

      // Simple heuristic: try to extract package name from asset name
      final parts = asset.name.split('_');
      for (var part in parts) {
        if (part.contains('.') && part.split('.').length >= 3) {
          // Likely a package name like com.example.app
          final pkg = part.replaceAll('.apk', '').replaceAll('.aab', '');
          final meta = await fetchAppMeta(pkg);
          if (meta != null && mounted) {
            setState(() {
              asset.imageLink = meta.icon;
            });
            break;
          }
        }
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
                        _processDownload(asset);
                      },
                    ),

                    // Option 2: Same as Option 1 (Download & Install)
                    _actionButton(
                      icon: Icons.save_alt,
                      label: 'Download & Install (same as above)',
                      color: Theme.of(context).colorScheme.secondary,
                      onTap: () {
                        Navigator.pop(context);
                        _processDownload(asset);
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


  Future<void> _processDownload(GithubAsset asset) async {
    if (!mounted) return;

    // Show the dialog before starting the download so that any
    // synchronous error callbacks can safely dismiss it.
    _showDownloadDialog(asset);

    final downloadFuture = _downloadCoordinator.startDownload(
      DownloadRequest(
        name: asset.name,
        url: asset.downloadUrl,
        digest: asset.digest,
      ),
      onCompleted: () {
        if (!mounted) return;
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        _snack('Installation started');
      },
      onError: (message) {
        if (!mounted) return;
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        _snack(message);
      },
    );
    await downloadFuture;
  }

  Future<void> _showDownloadDialog(GithubAsset asset) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.download_rounded,
                      size: 32,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Downloading',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    asset.name,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 32),
                  ValueListenableBuilder<double>(
                    valueListenable: _downloadCoordinator.progressNotifier,
                    builder: (context, value, _) {
                      return Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: value,
                              minHeight: 12,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${(value * 100).toStringAsFixed(0)}%',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<String>(
                    valueListenable: _downloadCoordinator.statusNotifier,
                    builder: (context, value, _) {
                      if (value.endsWith('%')) return const SizedBox.shrink();
                      return Text(
                        value,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: () {
                      _downloadCoordinator.cancelDownload();
                      Navigator.pop(context);
                      _snack('Download cancelled');
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel Download'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'manage') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RepoDataList()),
                ).then((_) {
                  // Refresh when returning from settings
                  _fetchReleases();
                });
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'manage',
                child: Row(
                  children: [
                    Icon(
                      Icons.settings,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    const SizedBox(width: 12),
                    const Text('Manage Repositories'),
                  ],
                ),
              ),
            ],
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
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.view_list),
                    title: const Text('All Apps'),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onRepoChanged(-1);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.library_add),
                    title: const Text('Manage Repositories'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RepoDataList(),
                        ),
                      ).then((_) {
                        // Refresh when returning from settings
                        _fetchReleases();
                      });
                    },
                  ),
                ],
              ),
            )
          : null,
      body: _buildBody(),
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
                        leading: asset.imageLink != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  asset.imageLink!,
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, _, _) => Icon(
                                    Icons.extension,
                                    size: 32,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondary,
                                  ),
                                ),
                              )
                            : Icon(
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

class AllAppsView extends StatefulWidget {
  final List<RepoData> repos;
  final Function(int) onRepoChanged;

  const AllAppsView({
    super.key,
    required this.repos,
    required this.onRepoChanged,
  });

  @override
  State<AllAppsView> createState() => _AllAppsViewState();
}

class _AllAppsViewState extends State<AllAppsView> {
  final Dio _dio = Dio();
  bool _isLoading = true;
  List<Map<String, dynamic>> _allAssets = []; // Store assets with repo info
  String? _errorMessage;
  final DownloadCoordinator _downloadCoordinator = DownloadCoordinator();

  @override
  void initState() {
    super.initState();
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _fetchAllReleases();
  }

  @override
  void dispose() {
    _downloadCoordinator.dispose();
    super.dispose();
  }

  Future<void> _fetchAllReleases() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _allAssets = [];
      });

      // Fetch from all repositories
      for (final repo in widget.repos) {
        try {
          var response = await _dio.get(
            'https://api.github.com/repos/${repo.userName}/${repo.repoName}/releases/latest',
          );

          final data = response.data;
          if (data is Map<String, dynamic> && data.containsKey('assets')) {
            final List<dynamic> assetsJson = data['assets'] ?? [];
            final List<GithubAsset> repoAssets = assetsJson
                .map((e) => GithubAsset.fromJson(e))
                .where(
                  (asset) =>
                      asset.name.toLowerCase().endsWith('.apk') ||
                      asset.name.toLowerCase().endsWith('.aab'),
                )
                .toList();

            // Add repo info to each asset
            for (final asset in repoAssets) {
              _allAssets.add({'asset': asset, 'repo': repo});
            }
          }
        } catch (e) {
          log('Error fetching from ${repo.userName}/${repo.repoName}: $e');
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_allAssets.isEmpty) {
            _errorMessage =
                'No assets found. Please check your internet or repository list.';
          }
        });

        // Fetch metadata for All Apps
        _fetchMetadataForAllAssets();
      }
    } catch (e) {
      log(e.toString());
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'An unexpected error occurred.';
        });
      }
    }
  }

  Future<void> _fetchMetadataForAllAssets() async {
    for (var item in _allAssets) {
      final GithubAsset asset = item['asset'] as GithubAsset;
      if (asset.imageLink != null) continue;

      final parts = asset.name.split('_');
      for (var part in parts) {
        if (part.contains('.') && part.split('.').length >= 3) {
          final pkg = part.replaceAll('.apk', '').replaceAll('.aab', '');
          final meta = await fetchAppMeta(pkg);
          if (meta != null && mounted) {
            setState(() {
              asset.imageLink = meta.icon;
            });
            break;
          }
        }
      }
    }
  }

  void _showActionOptions(GithubAsset asset, RepoData repo) {
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
                  'From: ${repo.userName}/${repo.repoName}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Option 1: Download & Install (Cache -> Open)
                    _actionButton(
                      icon: Icons.system_update,
                      label: 'Download & Install',
                      color: Theme.of(context).colorScheme.primary,
                      onTap: () {
                        Navigator.pop(context);
                        _processDownload(asset);
                      },
                    ),

                    // Option 2: Open in Browser
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

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }


  Future<void> _processDownload(GithubAsset asset) async {
    if (!mounted) return;

    // Show the dialog first so that any synchronous failure in startDownload
    // can still be reflected in the UI and the dialog can be properly closed.
    final dialogFuture = _showDownloadDialog(asset);

    Future<void> downloadFuture;
    try {
      downloadFuture = _downloadCoordinator.startDownload(
        DownloadRequest(
          name: asset.name,
          url: asset.downloadUrl,
          digest: asset.digest,
        ),
        onCompleted: () {
          if (!mounted) return;
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          _snack('Installation started');
        },
        onError: (message) {
          if (!mounted) return;
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          _snack(message);
        },
      );
    } catch (e, st) {
      // Handle any synchronous error from startDownload by closing the dialog
      // (if it is shown) and notifying the user.
      log('Failed to start download: $e', stackTrace: st);
      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _snack('Failed to start download');
      return;
    }

    await downloadFuture;
    // Ensure the dialog has completed (i.e. been popped) before finishing.
    await dialogFuture;
  }

  Future<void> _showDownloadDialog(GithubAsset asset) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.download_rounded,
                      size: 32,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Downloading',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    asset.name,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 32),
                  ValueListenableBuilder<double>(
                    valueListenable: _downloadCoordinator.progressNotifier,
                    builder: (context, value, _) {
                      return Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: value,
                              minHeight: 12,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${(value * 100).toStringAsFixed(0)}%',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<String>(
                    valueListenable: _downloadCoordinator.statusNotifier,
                    builder: (context, value, _) {
                      if (value.endsWith('%')) return const SizedBox.shrink();
                      return Text(
                        value,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: () {
                      _downloadCoordinator.cancelDownload();
                      Navigator.pop(context);
                      _snack('Download cancelled');
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel Download'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Apps'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'manage') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RepoDataList()),
                ).then((_) {
                  // Refresh when returning from settings
                  _fetchAllReleases();
                });
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'manage',
                child: Row(
                  children: [
                    Icon(
                      Icons.settings,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    const SizedBox(width: 12),
                    const Text('Manage Repositories'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      drawer: Drawer(
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
                leading: const Icon(Icons.code),
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
                onTap: () {
                  Navigator.pop(context);
                  widget.onRepoChanged(index);
                },
              );
            }),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.view_list,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('All Apps'),
              selected: true,
              onTap: () {
                Navigator.pop(context);
                // Already on All Apps
              },
            ),
            ListTile(
              leading: const Icon(Icons.library_add),
              title: const Text('Manage Repositories'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RepoDataList()),
                ).then((_) {
                  // Refresh when returning from settings
                  _fetchAllReleases();
                });
              },
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAllReleases,
        child: _errorMessage != null || _allAssets.isEmpty
            ? LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: constraints.maxHeight,
                      child: Center(
                        child: Text(
                          _errorMessage ??
                              'No apps found across all repositories.',
                        ),
                      ),
                    ),
                  );
                },
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _allAssets.length,
                itemBuilder: (context, index) {
                  final item = _allAssets[index];
                  final asset = item['asset'] as GithubAsset;
                  final repo = item['repo'] as RepoData;

                  return Card(
                    key: ValueKey(
                      '${repo.userName}-${repo.repoName}-${asset.id}',
                    ),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    elevation: 1,
                    child: InkWell(
                      onTap: () => _showActionOptions(asset, repo),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ListTile(
                          leading: asset.imageLink != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    asset.imageLink!,
                                    width: 32,
                                    height: 32,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, _, _) => Icon(
                                      Icons.extension,
                                      size: 32,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.secondary,
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.extension,
                                  size: 32,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                ),
                          title: Text(
                            asset.name,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          subtitle: Text(
                            '${repo.userName}/${repo.repoName}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
