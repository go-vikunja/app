import 'dart:async';

import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/online/cache_entry.dart';
import 'package:vikunja_mobile/core/repositories/project_repository.dart';

/// Keeps one account's projects in memory; step 6 replaces it with Drift.
final class OnlineProjectRepository implements ProjectRepository {
  new(this._client);

  final VikunjaReadClient _client;
  final _projects = CacheEntry<List<Project>>();
  var _disposed = false;

  @override
  Stream<List<Project>> watchAll() {
    if (_projects.isEmpty) {
      // A failure reaches the subscribers through the stream.
      unawaited(refresh().then<void>((_) {}, onError: (Object _) {}));
    }
    return _projects.watch();
  }

  @override
  Future<void> refresh() => _projects.loadOnce(_load);

  @override
  Project? find(int id) {
    for (final project in _projects.value ?? const <Project>[]) {
      if (project.id == id) return project;
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    _projects.dispose();
  }

  Future<void> _load() async {
    try {
      final projects = await _client.projects.listAll();
      if (_disposed) return;
      _projects.set(List.unmodifiable(projects));
    } on Object catch (error, stackTrace) {
      if (!_disposed && _projects.isEmpty) _projects.fail(error, stackTrace);
      rethrow;
    }
  }
}
