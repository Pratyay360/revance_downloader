import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show CustomSemanticsAction;
import 'package:shared_preferences/shared_preferences.dart';



class RepoData {
  final String userName;
  final String repoName;

  const RepoData({required this.userName, required this.repoName});

  // Convert to JSON for saving
  Map<String, dynamic> toJson() => {'userName': userName, 'repoName': repoName};

  // Create from JSON
  factory RepoData.fromJson(Map<String, dynamic> json) =>
      RepoData(userName: json['userName'], repoName: json['repoName']);
}

// Key for storage
const String _repoStorageKey = 'repo_list';

// Save the list of repos
Future<void> saveRepoDataList(List<RepoData> repos) async {
  final prefs = await SharedPreferences.getInstance();
  final List<String> stringList = repos
      .map((repo) => jsonEncode(repo.toJson()))
      .toList();
  await prefs.setStringList(_repoStorageKey, stringList);
}

// Load the list of repos
Future<List<RepoData>> loadRepoDataList() async {
  final prefs = await SharedPreferences.getInstance();
  final List<String>? stringList = prefs.getStringList(_repoStorageKey);

  if (stringList == null) return [];

  return stringList.map((stringRepo) {
    return RepoData.fromJson(jsonDecode(stringRepo));
  }).toList();
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

  Future<void> _addRepo(String user, String repo) async {
    final newRepo = RepoData(userName: user, repoName: repo);
    setState(() {
      _repos.add(newRepo);
    });
    await saveRepoDataList(_repos);
  }

  Future<void> _deleteRepo(int index) async {
    final deletedRepo = _repos[index];
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
                _repos.insert(index, deletedRepo);
              });
              await saveRepoDataList(_repos);
            },
          ),
        ),
      );
    }
  }

  void _showAddDialog() {
    final userController = TextEditingController();
    final repoController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Repository'),
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
              if (userController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a user name')),
                );
                return;
              }
              if (repoController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a repo name')),
                );
                return;
              }
              await _addRepo(
                userController.text.trim(),
                repoController.text.trim(),
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Repository List'), elevation: 0),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
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
                    trailing: Semantics(
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
                  ),
                );
              },
            ),
    );
  }
}
