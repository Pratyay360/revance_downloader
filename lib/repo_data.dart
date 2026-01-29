import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show CustomSemanticsAction;
import 'package:shared_preferences/shared_preferences.dart';
import 'secrets.dart' as secrets;

/// Lightweight value object representing a repository.
class RepoData {
  final String userName;
  final String repoName;
  final bool isReadOnly;

  const RepoData({
    required this.userName,
    required this.repoName,
    this.isReadOnly = false,
  });

  Map<String, dynamic> toJson() => {
    'userName': userName,
    'repoName': repoName,
    'isReadOnly': isReadOnly,
  };

  /// Be lenient when parsing stored data — callers (load) handle malformed
  /// entries by skipping them.
  factory RepoData.fromJson(Map<String, dynamic> json) {
    final user = json['userName'];
    final repo = json['repoName'];
    if (user is! String || repo is! String) {
      throw const FormatException('Invalid RepoData JSON');
    }
    return RepoData(
      userName: user,
      repoName: repo,
      isReadOnly: json['isReadOnly'] == true,
    );
  }

  @override
  String toString() =>
      'RepoData($userName/$repoName${isReadOnly ? ', readOnly' : ''})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepoData &&
          userName.toLowerCase() == other.userName.toLowerCase() &&
          repoName.toLowerCase() == other.repoName.toLowerCase() &&
          isReadOnly == other.isReadOnly;

  @override
  int get hashCode =>
      Object.hash(userName.toLowerCase(), repoName.toLowerCase(), isReadOnly);
}

const String _repoStorageKey = 'repo_list';

/// Persistence helper extracted for clarity and easier testing.
class RepoStorage {
  const RepoStorage._();

  static Future<void> save(List<RepoData> repos) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> stringList = repos
        .where((r) => !r.isReadOnly)
        .map((r) => jsonEncode(r.toJson()))
        .toList();
    await prefs.setStringList(_repoStorageKey, stringList);
  }

  static Future<List<RepoData>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? raw = prefs.getStringList(_repoStorageKey);
    final List<RepoData> result = [];

    if (raw != null) {
      for (final item in raw) {
        try {
          final decoded = jsonDecode(item);
          if (decoded is Map<String, dynamic>) {
            result.add(RepoData.fromJson(Map<String, dynamic>.from(decoded)));
          }
        } catch (e) {
          // keep running on malformed entries
          debugPrint('Skipping invalid repo entry in storage: $e');
        }
      }
    }

    // ensure the secret/default repo is always first and read-only
    result.removeWhere(
      (r) => r.userName == secrets.userName1 && r.repoName == secrets.repoName1,
    );
    result.insert(
      0,
      RepoData(
        userName: secrets.userName1,
        repoName: secrets.repoName1,
        isReadOnly: true,
      ),
    );

    return result;
  }
}

// Backward-compatible top-level functions
Future<void> saveRepoDataList(List<RepoData> repos) => RepoStorage.save(repos);
Future<List<RepoData>> loadRepoDataList() => RepoStorage.load();

class RepoDataList extends StatefulWidget {
  const RepoDataList({super.key});

  @override
  State<RepoDataList> createState() => _RepoDataListState();
}

class _RepoDataListState extends State<RepoDataList> {
  List<RepoData> _repos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRepos();
  }

  Future<void> _loadRepos() async {
    try {
      final repos = await loadRepoDataList();
      if (!mounted) return;
      setState(() {
        _repos = repos;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack('Error loading repos: $e', isError: true);
    }
  }

  void _showSnack(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          text,
          style: TextStyle(
            color: isError
                ? Theme.of(context).colorScheme.onErrorContainer
                : null,
          ),
        ),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.errorContainer
            : null,
      ),
    );
  }

  bool _isDuplicate(String user, String repo, {int? excludeIndex}) {
    final u = user.toLowerCase();
    final r = repo.toLowerCase();
    return _repos.asMap().entries.any((entry) {
      if (excludeIndex != null && entry.key == excludeIndex) return false;
      final existing = entry.value;
      return existing.userName.toLowerCase() == u &&
          existing.repoName.toLowerCase() == r;
    });
  }

  Future<void> _addRepo(String user, String repo) async {
    if (_isDuplicate(user, repo)) {
      _showSnack('Repository already exists');
      return;
    }

    setState(() => _repos.add(RepoData(userName: user, repoName: repo)));
    await saveRepoDataList(_repos);
  }

  Future<void> _editRepo(int index, String user, String repo) async {
    if (index < 0 || index >= _repos.length) return;
    if (_repos[index].isReadOnly) {
      _showSnack('Cannot edit read-only repository');
      return;
    }

    if (_isDuplicate(user, repo, excludeIndex: index)) {
      _showSnack('Another repository with same name exists');
      return;
    }

    setState(() => _repos[index] = RepoData(userName: user, repoName: repo));
    await saveRepoDataList(_repos);
  }

  Future<void> _deleteRepo(int index) async {
    if (index < 0 || index >= _repos.length) return;
    final deleted = _repos[index];
    if (deleted.isReadOnly) return;

    setState(() => _repos.removeAt(index));
    await saveRepoDataList(_repos);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted ${deleted.repoName}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            setState(() {
              final insertIndex = index.clamp(0, _repos.length);
              _repos.insert(insertIndex, deleted);
            });
            await saveRepoDataList(_repos);
          },
        ),
      ),
    );
  }

  void _showAddDialog({int? index, String? initialUser, String? initialRepo}) {
    showDialog<void>(
      context: context,
      builder: (context) => _RepoEditDialog(
        initialUser: initialUser,
        initialRepo: initialRepo,
        isEditing: index != null,
        onSubmit: (user, repo) =>
            index == null ? _addRepo(user, repo) : _editRepo(index, user, repo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Repository List'), elevation: 0),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(),
        tooltip: 'Add a new repository',
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _repos.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_off_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No repositories found',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first repository to get started',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _repos.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, index) {
                final repo = _repos[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  elevation: 1,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.code,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    title: Text(
                      repo.repoName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    subtitle: Text(
                      repo.userName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    trailing: repo.isReadOnly
                        ? Tooltip(
                            message: 'Default repository (Read-only)',
                            child: Icon(
                              Icons.lock_outline,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.edit,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                tooltip: 'Edit repository',
                                onPressed: () => _showAddDialog(
                                  index: index,
                                  initialUser: repo.userName,
                                  initialRepo: repo.repoName,
                                ),
                              ),
                              Semantics(
                                customSemanticsActions: {
                                  CustomSemanticsAction(label: 'delete'): () =>
                                      _deleteRepo(index),
                                },
                                child: IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  tooltip: 'Delete repository',
                                  onPressed: () => _deleteRepo(index),
                                ),
                              ),
                            ],
                          ),
                  ),
                );
              },
            ),
    );
  }
}

/// Dialog extracted to avoid controller/validation duplication and leaking.
class _RepoEditDialog extends StatefulWidget {
  final String? initialUser;
  final String? initialRepo;
  final bool isEditing;
  final Future<void> Function(String user, String repo) onSubmit;

  const _RepoEditDialog({
    this.initialUser,
    this.initialRepo,
    required this.isEditing,
    required this.onSubmit,
  });

  @override
  State<_RepoEditDialog> createState() => _RepoEditDialogState();
}

class _RepoEditDialogState extends State<_RepoEditDialog> {
  late final TextEditingController _userController = TextEditingController(
    text: widget.initialUser,
  );
  late final TextEditingController _repoController = TextEditingController(
    text: widget.initialRepo,
  );
  bool _inFlight = false;

  @override
  void dispose() {
    _userController.dispose();
    _repoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = _userController.text.trim();
    final repo = _repoController.text.trim();
    if (user.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a user name')));
      return;
    }
    if (repo.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a repo name')));
      return;
    }

    setState(() => _inFlight = true);
    try {
      await widget.onSubmit(user, repo);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _inFlight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEditing ? 'Edit Repository' : 'Add Repository'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _userController,
            decoration: InputDecoration(
              labelText: 'User Name',
              prefixIcon: const Icon(Icons.person),
              hintText: 'e.g., bitwarden',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _repoController,
            decoration: InputDecoration(
              labelText: 'Repo Name',
              prefixIcon: const Icon(Icons.code),
              hintText: 'e.g., android',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _inFlight ? null : _submit,
          child: Text(widget.isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
