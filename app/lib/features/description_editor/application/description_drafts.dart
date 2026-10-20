import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';
import 'package:vikunja_mobile/features/description_editor/application/description_target.dart';

part 'description_drafts.g.dart';

@riverpod
DescriptionDrafts descriptionDrafts(Ref ref) =>
    DescriptionDrafts(ref.watch(preferencesStoreProvider));

/// An edit the editor held, unsaved, and the description it started from.
@immutable
final class DescriptionDraft {
  const new({required this.html, required this.base});

  final String html;
  final String base;
}

/// The unsaved edit of the editor that was open when the app last went to
/// the background, so that it outlives the system ending the app meanwhile.
/// One slot, as one editor is open at a time; this is no autosave, the
/// task or project changes only on Save.
final class DescriptionDrafts {
  new(this._store);

  static const key = 'description_editor.draft';

  final PreferencesStore _store;

  Future<DescriptionDraft?> read({
    required String account,
    required DescriptionTarget target,
  }) async {
    final stored = await _decoded();
    if (stored == null ||
        stored['account'] != account ||
        stored['target'] != _targetKey(target)) {
      return null;
    }
    return switch ((stored['html'], stored['base'])) {
      (final String html, final String base) => DescriptionDraft(
        html: html,
        base: base,
      ),
      _ => null,
    };
  }

  Future<void> save(
    DescriptionDraft draft, {
    required String account,
    required DescriptionTarget target,
  }) => _store.setString(
    key,
    jsonEncode({
      'account': account,
      'target': _targetKey(target),
      'html': draft.html,
      'base': draft.base,
    }),
  );

  /// Removes the draft when it is [target]'s, so that another editor
  /// leaves a draft it does not know about alone.
  Future<void> discard({
    required String account,
    required DescriptionTarget target,
  }) async {
    final stored = await _decoded();
    if (stored == null ||
        (stored['account'] == account &&
            stored['target'] == _targetKey(target))) {
      await _store.remove(key);
    }
  }

  Future<Map<String, Object?>?> _decoded() async {
    final raw = await _store.getString(key);
    if (raw == null) return null;
    try {
      return switch (jsonDecode(raw)) {
        final Map<String, Object?> map => map,
        _ => null,
      };
    } on FormatException {
      return null;
    }
  }

  static String _targetKey(DescriptionTarget target) => switch (target) {
    TaskDescriptionTarget(:final taskId) => 'task:$taskId',
    ProjectDescriptionTarget(:final projectId) => 'project:$projectId',
  };
}
