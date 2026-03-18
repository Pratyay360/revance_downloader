import 'dart:async';
import 'dart:io';

import 'package:app_installer/app_installer.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_file_downloader/flutter_file_downloader.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rd_manager/notifications.dart';
import 'package:sqflite/sqflite.dart';

class DownloadRequest {
  final String name;
  final String url;
  final String digest;

  const DownloadRequest({
    required this.name,
    required this.url,
    required this.digest,
  });
}

class DownloadHistoryStore {
  DownloadHistoryStore._();

  static final DownloadHistoryStore instance = DownloadHistoryStore._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;

    _db = await openDatabase(
      'downloads.db',
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE downloads(name TEXT PRIMARY KEY, digest TEXT, path TEXT)',
        );
      },
    );

    return _db!;
  }

  Future<void> insert({
    required String name,
    required String digest,
    required String path,
  }) async {
    final db = await database;
    await db.insert('downloads', {
      'digest': digest,
      'name': name,
      'path': path,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

class DownloadCoordinator {
  final ValueNotifier<double> progressNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<String> statusNotifier = ValueNotifier<String>('Starting...');

  Timer? _watchdog;
  Completer<void>? _completion;
  int? _downloadId;
  bool _isCancelled = false;
  bool _isRunning = false;
  VoidCallback? _onCancelled;

  bool get isRunning => _isRunning;

  Future<void> startDownload(
    DownloadRequest request, {
    Duration inactivityTimeout = const Duration(seconds: 60),
    VoidCallback? onCompleted,
    ValueChanged<String>? onError,
    VoidCallback? onCancelled,
  }) async {
    if (_isRunning) {
      return Future.error(
        StateError('A download is already in progress.'),
      );
    }

    if (Platform.isAndroid) {
      await Permission.notification.request();
    }

    _isRunning = true;
    _isCancelled = false;
    _downloadId = null;
    _onCancelled = onCancelled;
    progressNotifier.value = 0;
    statusNotifier.value = 'Starting...';
    _completion = Completer<void>();

    _resetWatchdog(timeout: inactivityTimeout, onTimeout: () {
      cancelDownload();
      onError?.call('Download timed out due to inactivity.');
    });

    FileDownloader.downloadFile(
      url: request.url,
      name: request.name,
      notificationType: NotificationType.all,
      onDownloadRequestIdReceived: (id) {
        _downloadId = id;
      },
      onProgress: (_, progress) {
        if (_isCancelled) return;

        _resetWatchdog(timeout: inactivityTimeout, onTimeout: () {
          cancelDownload();
          onError?.call('Download timed out due to inactivity.');
        });
        progressNotifier.value = progress / 100;
        statusNotifier.value = '${progress.toStringAsFixed(1)}%';
      },
      onDownloadError: (message) {
        _finish();
        if (_isCancelled) return;
        onError?.call('Download error: $message');
      },
      onDownloadCompleted: (path) async {
        if (_isCancelled) {
          _finish();
          return;
        }

        try {
          statusNotifier.value = 'Verifying download...';
          await _verifyDigest(path: path, digest: request.digest);

          statusNotifier.value = 'Saving download metadata...';
          await DownloadHistoryStore.instance.insert(
            name: request.name,
            digest: request.digest,
            path: path,
          );

          statusNotifier.value = 'Launching installer...';
          await AppInstaller.installApk(path);
          await NotificationsService.showNotification(
            id: 2,
            title: 'Installation',
            body: 'Installer opened successfully',
          );

          _finish();
          onCompleted?.call();
        } catch (e) {
          _finish();
          onError?.call('Install failed: $e');
        }
      },
    );

    return _completion!.future;
  }

  void cancelDownload() {
    if (!_isRunning || _isCancelled) return;

    _isCancelled = true;
    final id = _downloadId;
    if (id != null) {
      FileDownloader.cancelDownload(id);
    }
    _onCancelled?.call();
    _finish();
  }

  void dispose() {
    _watchdog?.cancel();
    progressNotifier.dispose();
    statusNotifier.dispose();
  }

  void _resetWatchdog({
    required Duration timeout,
    required VoidCallback onTimeout,
  }) {
    _watchdog?.cancel();
    _watchdog = Timer(timeout, onTimeout);
  }

  void _finish() {
    _watchdog?.cancel();
    _watchdog = null;
    _downloadId = null;
    _onCancelled = null;
    _isRunning = false;
    if (!(_completion?.isCompleted ?? true)) {
      _completion?.complete();
    }
  }

  Future<void> _verifyDigest({
    required String path,
    required String digest,
  }) async {
    final normalized = _normalizeDigest(digest);
    if (normalized == null) return;

    final file = File(path);
    if (!await file.exists()) {
      throw Exception('Downloaded file does not exist.');
    }

    final hash = await sha256.bind(file.openRead()).first;
    final computed = hash.toString();
    if (computed != normalized) {
      throw Exception('Digest mismatch detected.');
    }
  }

  String? _normalizeDigest(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return null;
    if (value.startsWith('sha256:')) return value.substring('sha256:'.length);
    if (RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) return value;
    return null;
  }
}
