import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/storage/draft_files.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';
import 'package:vikunja_mobile/features/description_editor/application/description_target.dart';

part 'description_drafts.g.dart';

// One for the app, so that the writes of every editor go one after the
// other.
@Riverpod(keepAlive: true)
DescriptionDrafts descriptionDrafts(Ref ref) =>
    DescriptionDrafts(ref.watch(draftStoreProvider));

/// An edit the editor held, unsaved, and the description it started from.
@immutable
final class DescriptionDraft {
  const new({required this.html, required this.base});

  final String html;
  final String base;
}

/// The server id a temporary [id] of a task or a label was given once its
/// create was answered; any other id as it is.
typedef IdResolver = Future<int> Function(int id);

/// The unsaved edits of the description editors, kept while editing, so
/// that they outlive the system ending the app: one per account and
/// description, the [maxDrafts] most recently saved in all. This is no
/// autosave, the task or project changes only on Save. Signing out drops
/// the account's.
///
/// A task's or a label's draft names the id the editor had, which for one
/// created offline is a temporary one until the create is answered; with
/// an [IdResolver] for the target's kind, reading, saving and discarding
/// follow it to the server id.
final class DescriptionDrafts {
  new(this._store);

  static const key = 'description_editor.drafts';
  static const maxDrafts = 20;

  /// A lookup that does not answer must not hold the writes after it.
  static const _resolveTimeout = Duration(seconds: 2);

  final PreferencesStore _store;
  Future<void> _writes = Future.value();

  Future<DescriptionDraft?> read({
    required String account,
    required DescriptionTarget target,
    IdResolver? resolveId,
  }) async {
    await _writes;
    for (final entry in (await _entries()).reversed) {
      if (entry['account'] == account &&
          await _isFor(entry['target'], target, resolveId)) {
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

  /// Replaces [target]'s draft, the one under its temporary id too.
  Future<void> save(
    DescriptionDraft draft, {
    required String account,
    required DescriptionTarget target,
    IdResolver? resolveId,
  }) => _change((entries) async {
    await _removeFor(entries, account, target, resolveId);
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
    IdResolver? resolveId,
  }) => _change((entries) => _removeFor(entries, account, target, resolveId));

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
    IdResolver? resolveId,
  ) async {
    final kept = [
      for (final entry in entries)
        if (entry['account'] != account ||
            !await _isFor(entry['target'], target, resolveId))
          entry,
    ];
    entries
      ..clear()
      ..addAll(kept);
  }

  static Future<bool> _isFor(
    Object? stored,
    DescriptionTarget target,
    IdResolver? resolveId,
  ) async {
    if (stored == _targetKey(target)) return true;
    final (prefix, targetId) = switch (target) {
      TaskDescriptionTarget(:final taskId) => (_taskPrefix, taskId),
      LabelDescriptionTarget(:final labelId) => (_labelPrefix, labelId),
      _ => (null, 0),
    };
    if (resolveId == null ||
        prefix == null ||
        stored is! String ||
        !stored.startsWith(prefix)) {
      return false;
    }
    final storedId = int.tryParse(stored.substring(prefix.length));
    if (storedId == null || (storedId > 0 && targetId > 0)) return false;
    Future<int> resolved(int id) async => id > 0
        ? id
        : await resolveId(id)
              .timeout(_resolveTimeout, onTimeout: () => id)
              .catchError((_) => id);
    return await resolved(storedId) == await resolved(targetId);
  }

  static const _taskPrefix = 'task:';
  static const _labelPrefix = 'label:';

  static String _targetKey(DescriptionTarget target) => switch (target) {
    TaskDescriptionTarget(:final taskId) => '$_taskPrefix$taskId',
    ProjectDescriptionTarget(:final projectId) => 'project:$projectId',
    LabelDescriptionTarget(:final labelId) => '$_labelPrefix$labelId',
    SavedFilterDescriptionTarget(:final pseudoProjectId) =>
      'filter:$pseudoProjectId',
    TeamDescriptionTarget(:final teamId) => 'team:$teamId',
    CommentTarget(:final taskId, :final comment) =>
      'comment:$taskId:${comment.id}',
  };
}
