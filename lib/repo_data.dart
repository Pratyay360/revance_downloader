import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show CustomSemanticsAction;
import 'package:shared_preferences/shared_preferences.dart';
import 'secrets.dart' as secrets;

class RepoData {
  final String userName;
  final String repoName;
  final bool isReadOnly;

  const RepoData({
    required this.userName,
    required this.repoName,
    this.isReadOnly = false,
  });

  // Convert to JSON for saving. `isReadOnly` is included for future-proofing
  Map<String, dynamic> toJson() => {
    'userName': userName,
    'repoName': repoName,
    'isReadOnly': isReadOnly,
  };

  // Create from JSON. Be forgiving for missing keys (backwards compatibility).
  factory RepoData.fromJson(Map<String, dynamic> json) => RepoData(
    userName: json['userName'] as String,
    repoName: json['repoName'] as String,
    isReadOnly: json['isReadOnly'] == true,
  );
}

// Key for storage
const String _repoStorageKey = 'repo_list';

// Save the list of repos (exclude read-only entries)
Future<void> saveRepoDataList(List<RepoData> repos) async {
  final prefs = await SharedPreferences.getInstance();
  final List<String> stringList = repos
      .where((repo) => !repo.isReadOnly)
      .map((repo) => jsonEncode(repo.toJson()))
      .toList();
  await prefs.setStringList(_repoStorageKey, stringList);
}

Future<List<RepoData>> loadRepoDataList() async {
  final prefs = await SharedPreferences.getInstance();
  final List<String>? stringList = prefs.getStringList(_repoStorageKey);

  final List<RepoData> loaded = [];
  if (stringList != null) {
    for (final stringRepo in stringList) {
      try {
        final decoded = jsonDecode(stringRepo);
        if (decoded is Map<String, dynamic>) {
          loaded.add(RepoData.fromJson(Map<String, dynamic>.from(decoded)));
        }
      } catch (e) {
        // Skip malformed entries but keep running — do not crash the app on bad stored data.
        debugPrint('Skipping invalid repo entry in storage: $e');
      }
    }
  }

  // Remove duplicate/stale default repo if it exists in storage
  loaded.removeWhere(
    (r) => r.userName == secrets.userName && r.repoName == secrets.repoName,
  );

  // Prepend the secret/default repo as read-only
  loaded.insert(
    0,
    RepoData(
      userName: secrets.userName,
      repoName: secrets.repoName,
      isReadOnly: true,
    ),
  );

  return loaded;
}

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
      if (mounted) {
        setState(() {
          _repos = repos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error loading repos: $e',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
    }
  }

  bool _isDuplicate(String user, String repo, {int? excludeIndex}) {
    final u = user.toLowerCase();
    final r = repo.toLowerCase();
    for (var i = 0; i < _repos.length; i++) {
      if (excludeIndex != null && i == excludeIndex) continue;
      final existing = _repos[i];
      if (existing.userName.toLowerCase() == u &&
          existing.repoName.toLowerCase() == r) {
        return true;
      }
    }
    return false;
  }

  Future<void> _addRepo(String user, String repo) async {
    if (_isDuplicate(user, repo)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Repository already exists')),
        );
      }
      return;
    }

    final newRepo = RepoData(userName: user, repoName: repo);
    setState(() {
      _repos.add(newRepo);
    });
    await saveRepoDataList(_repos);
  }

  Future<void> _editRepo(int index, String user, String repo) async {
    if (index < 0 || index >= _repos.length) return;
    if (_repos[index].isReadOnly) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot edit read-only repository')),
        );
      }
      return;
    }

    if (_isDuplicate(user, repo, excludeIndex: index)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Another repository with same name exists'),
          ),
        );
      }
      return;
    }

    final updatedRepo = RepoData(userName: user, repoName: repo);
    setState(() {
      _repos[index] = updatedRepo;
    });
    await saveRepoDataList(_repos);
  }

  Future<void> _deleteRepo(int index) async {
    if (index < 0 || index >= _repos.length) return;
    final deletedRepo = _repos[index];
    if (deletedRepo.isReadOnly) return;

    setState(() {
      _repos.removeAt(index);
    });

    await saveRepoDataList(_repos);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted ${deletedRepo.repoName}'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              setState(() {
                final insertIndex = index.clamp(0, _repos.length);
                _repos.insert(insertIndex, deletedRepo);
              });
              await saveRepoDataList(_repos);
            },
          ),
        ),
      );
    }
  }

  void _showAddDialog({int? index, String? initialUser, String? initialRepo}) {
    final userController = TextEditingController(text: initialUser);
    final repoController = TextEditingController(text: initialRepo);
    final isEditing = index != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Repository' : 'Add Repository'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userController,
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
              controller: repoController,
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
            onPressed: () async {
              final userText = userController.text.trim();
              final repoText = repoController.text.trim();

              if (userText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a user name')),
                );
                return;
              }
              if (repoText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a repo name')),
                );
                return;
              }

              if (isEditing) {
                await _editRepo(index, userText, repoText);
              } else {
                await _addRepo(userText, repoText);
              }

              if (context.mounted) Navigator.pop(context);
            },
            child: Text(isEditing ? 'Save' : 'Add'),
          ),
        ],
      ),
    ).then((_) {
      // Dispose controllers after the dialog is closed to avoid leaks.
      userController.dispose();
      repoController.dispose();
    });
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
