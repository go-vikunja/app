import 'dart:async';

import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/online/cache_entry.dart';
import 'package:vikunja_mobile/core/repositories/paged_list.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';

final _log = Logger('OnlineTaskRepository');

typedef _ProjectKey = ({int projectId, bool showDone});

/// Keeps one account's task lists in memory; step 6 replaces it with Drift.
final class OnlineTaskRepository implements TaskRepository {
  new(this._client);

  /// The overview fetches every page up to this many.
  static const openTasksPageCap = 5;

  final VikunjaReadClient _client;
  final _openTasks = CacheEntry<List<Task>>();
  final _projectTasks = <_ProjectKey, _ProjectTasks>{};
  var _disposed = false;

  @override
  Stream<List<Task>> watchOpenTasks() {
    if (_openTasks.isEmpty) _quietly(refreshOpenTasks());
    return _openTasks.watch();
  }

  @override
  Stream<PagedList<Task>> watchProjectTasks(
    int projectId, {
    required bool showDone,
  }) {
    final key = (projectId: projectId, showDone: showDone);
    final slot = _slot(key);
    if (slot.entry.isEmpty) _quietly(_loadFirstPage(key));
    return slot.entry.watch();
  }

  @override
  Future<void> refreshOpenTasks() => _openTasks.loadOnce(_loadOpenTasks);

  @override
  Future<void> refreshProjectTasks(
    int projectId, {
    required bool showDone,
  }) async {
    await _loadFirstPage((projectId: projectId, showDone: showDone));
    // The list with the other "show done" setting shows the same tasks and
    // is just as old by now.
    _invalidate((projectId: projectId, showDone: !showDone));
  }

  @override
  Future<void> loadMoreProjectTasks(int projectId, {required bool showDone}) {
    final key = (projectId: projectId, showDone: showDone);
    final slot = _slot(key);
    final current = slot.entry.value;
    // A refresh in flight replaces every page, so there is nothing to append
    // to yet.
    if (current == null || !current.hasMore || slot.entry.isLoading) {
      return Future.value();
    }
    return slot.loadingMore ??= _loadProjectPage(key, page: slot.lastPage + 1)
        .whenComplete(() {
          slot.loadingMore = null;
        });
  }

  @override
  void dispose() {
    _disposed = true;
    _openTasks.dispose();
    for (final slot in _projectTasks.values) {
      slot.entry.dispose();
    }
  }

  _ProjectTasks _slot(_ProjectKey key) =>
      _projectTasks.putIfAbsent(key, _ProjectTasks.new);

  // A failure of a load started by a subscription reaches the subscribers
  // through the stream.
  void _quietly(Future<void> load) =>
      unawaited(load.then<void>((_) {}, onError: (Object _) {}));

  Future<void> _loadFirstPage(_ProjectKey key) {
    final slot = _slot(key);
    return slot.entry.loadOnce(() {
      slot.generation++;
      return _loadProjectPage(key, page: 1);
    });
  }

  void _invalidate(_ProjectKey key) {
    final slot = _projectTasks[key];
    if (slot == null || slot.entry.isEmpty) return;
    if (slot.entry.hasListener) {
      _quietly(_loadFirstPage(key));
    } else {
      slot.entry.clear();
      slot.lastPage = 0;
    }
  }

  Future<void> _loadOpenTasks() async {
    const query = TaskQuery(
      filter: 'done = false',
      sort: TaskQuery.dueDateSort,
    );
    try {
      final tasks = <Task>[];
      var page = 1;
      while (true) {
        final result = await _client.tasks.list(query.copyWith(page: page));
        tasks.addAll(result.items);
        if (!result.hasMore) break;
        if (page >= openTasksPageCap) {
          _log.warning(
            'Open tasks capped at $openTasksPageCap pages of '
            '${result.totalPages}',
          );
          break;
        }
        page++;
      }
      if (_disposed) return;
      _openTasks.set(List.unmodifiable(tasks));
    } on Object catch (error, stackTrace) {
      if (!_disposed && _openTasks.isEmpty) _openTasks.fail(error, stackTrace);
      rethrow;
    }
  }

  Future<void> _loadProjectPage(_ProjectKey key, {required int page}) async {
    final slot = _slot(key);
    final generation = slot.generation;
    final query = TaskQuery(
      filter: key.showDone ? null : 'done = false',
      sort: TaskQuery.defaultSort,
      page: page,
    );
    try {
      final result = await _client.tasks.listInProject(key.projectId, query);
      if (_disposed) return;
      // A refresh that started meanwhile replaces the pages this one would
      // have extended.
      if (generation != slot.generation) return;
      final previous = page == 1
          ? const <Task>[]
          : slot.entry.value?.items ?? const <Task>[];
      // A task that moved between pages while loading is kept once.
      final seen = {for (final task in previous) task.id};
      final items = [
        ...previous,
        for (final task in result.items)
          if (seen.add(task.id)) task,
      ];
      slot.lastPage = result.page;
      slot.entry.set(
        PagedList(items: List.unmodifiable(items), hasMore: result.hasMore),
      );
    } on Object catch (error, stackTrace) {
      if (!_disposed && slot.entry.isEmpty) slot.entry.fail(error, stackTrace);
      rethrow;
    }
  }
}

final class _ProjectTasks {
  final entry = CacheEntry<PagedList<Task>>();
  int lastPage = 0;
  Future<void>? loadingMore;

  /// Bumped by every first-page load, so that a load-more started before it
  /// cannot append to the fresh pages.
  int generation = 0;
}
