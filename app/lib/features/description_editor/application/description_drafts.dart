import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';
import 'package:vikunja_mobile/features/description_editor/application/description_target.dart';

part 'description_drafts.g.dart';

// One for the app, so that the writes of every editor go one after the
// other.
@Riverpod(keepAlive: true)
DescriptionDrafts descriptionDrafts(Ref ref) =>
    DescriptionDrafts(ref.watch(preferencesStoreProvider));

/// An edit the editor held, unsaved, and the description it started from.
@immutable
final class DescriptionDraft {
  const new({required this.html, required this.base});

  final String html;
  final String base;
}

/// The server id a task's temporary [taskId] was given once its create was
/// answered; any other id as it is.
typedef TaskIdResolver = Future<int> Function(int taskId);

/// The unsaved edits of the description editors, kept while editing, so
/// that they outlive the system ending the app: one per account and
/// description, the [maxDrafts] most recently saved in all. This is no
/// autosave, the task or project changes only on Save. Signing out drops
/// the account's.
///
/// A task's draft names the id the editor had, which for a task created
/// offline is a temporary one until the create is answered; with a
/// [TaskIdResolver], reading, saving and discarding follow it to the server
/// id.
final class DescriptionDrafts {
  new(this._store);

  static const key = 'description_editor.drafts';
  static const maxDrafts = 20;

  /// The one draft development builds kept before step 40b; what it holds
  /// is not taken over.
  static const _oneSlotKey = 'description_editor.draft';

  /// A lookup that does not answer must not hold the writes after it.
  static const _resolveTimeout = Duration(seconds: 2);

  final PreferencesStore _store;
  Future<void> _writes = Future.value();
  var _oneSlotChecked = false;

  Future<DescriptionDraft?> read({
    required String account,
    required DescriptionTarget target,
    TaskIdResolver? resolveTaskId,
  }) async {
    await _writes;
    for (final entry in (await _entries()).reversed) {
      if (entry['account'] == account &&
          await _isFor(entry['target'], target, resolveTaskId)) {
        return switch ((entry['html'], entry['base'])) {
          (final String html, final String base) => DescriptionDraft(
            html: html,
            base: base,
          ),
          _ => null,
        };
      }
    }
    return null;
  }

  /// Replaces [target]'s draft, the one under a task's temporary id too.
  Future<void> save(
    DescriptionDraft draft, {
    required String account,
    required DescriptionTarget target,
    TaskIdResolver? resolveTaskId,
  }) => _change((entries) async {
    await _removeFor(entries, account, target, resolveTaskId);
    entries.add({
      'account': account,
      'target': _targetKey(target),
      'html': draft.html,
      'base': draft.base,
    });
    if (entries.length > maxDrafts) {
      entries.removeRange(0, entries.length - maxDrafts);
    }
  });

  /// Removes [target]'s draft; the others stay.
  Future<void> discard({
    required String account,
    required DescriptionTarget target,
    TaskIdResolver? resolveTaskId,
  }) =>
      _change((entries) => _removeFor(entries, account, target, resolveTaskId));

  /// Removes [account]'s drafts, as the account signs out. One that names
  /// no account is no one's and goes too.
  Future<void> discardAll(String account) => _change(
    (entries) async => entries.removeWhere(
      (entry) => entry['account'] is! String || entry['account'] == account,
    ),
  );

  /// One write at a time: each reads what the one before wrote.
  Future<void> _change(
    Future<void> Function(List<Map<String, Object?>> entries) change,
  ) {
    final done = _writes.then((_) async {
      final entries = await _entries();
      await change(entries);
      if (entries.isEmpty) {
        await _store.remove(key);
      } else {
        await _store.setString(key, jsonEncode(entries));
      }
    });
    _writes = done.catchError((Object _) {});
    return done;
  }

  /// Oldest first.
  Future<List<Map<String, Object?>>> _entries() async {
    if (!_oneSlotChecked) {
      _oneSlotChecked = true;
      if (await _store.getString(_oneSlotKey) != null) {
        await _store.remove(_oneSlotKey);
      }
    }
    final raw = await _store.getString(key);
    if (raw == null) return [];
    try {
      return switch (jsonDecode(raw)) {
        final List<Object?> list => [
          for (final entry in list)
            if (entry case final Map<String, Object?> map) map,
        ],
        _ => [],
      };
    } on FormatException {
      return [];
    }
  }

  static Future<void> _removeFor(
    List<Map<String, Object?>> entries,
    String account,
    DescriptionTarget target,
    TaskIdResolver? resolveTaskId,
  ) async {
    final kept = [
      for (final entry in entries)
        if (entry['account'] != account ||
            !await _isFor(entry['target'], target, resolveTaskId))
          entry,
    ];
    entries
      ..clear()
      ..addAll(kept);
  }

  static Future<bool> _isFor(
    Object? stored,
    DescriptionTarget target,
    TaskIdResolver? resolveTaskId,
  ) async {
    if (stored == _targetKey(target)) return true;
    if (resolveTaskId == null ||
        target is! TaskDescriptionTarget ||
        stored is! String ||
        !stored.startsWith(_taskPrefix)) {
      return false;
    }
    final storedId = int.tryParse(stored.substring(_taskPrefix.length));
    if (storedId == null || (storedId > 0 && target.taskId > 0)) return false;
    Future<int> resolved(int id) async => id > 0
        ? id
        : await resolveTaskId(id)
              .timeout(_resolveTimeout, onTimeout: () => id)
              .catchError((_) => id);
    return await resolved(storedId) == await resolved(target.taskId);
  }

  static const _taskPrefix = 'task:';

  static String _targetKey(DescriptionTarget target) => switch (target) {
    TaskDescriptionTarget(:final taskId) => '$_taskPrefix$taskId',
    ProjectDescriptionTarget(:final projectId) => 'project:$projectId',
    LabelDescriptionTarget(:final labelId) => 'label:$labelId',
    SavedFilterDescriptionTarget(:final pseudoProjectId) =>
      'filter:$pseudoProjectId',
    TeamDescriptionTarget(:final teamId) => 'team:$teamId',
    CommentTarget(:final taskId, :final comment) =>
      'comment:$taskId:${comment.id}',
  };
}
