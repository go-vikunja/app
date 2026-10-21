import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';

part 'comment_drafts.g.dart';

@Riverpod(keepAlive: true)
CommentDrafts commentDrafts(Ref ref) =>
    CommentDrafts(ref.watch(preferencesStoreProvider));

/// A mention in `CommentComposerDraft.text`: the characters from `start`
/// to `end` stand for the user `username`, shown as `label`.
typedef DraftMention = ({int start, int end, String username, String label});

/// The comment a reply quotes, enough to quote it without the comment
/// loaded: its author's display name and its HTML.
typedef DraftReply = ({int commentId, String author, String html});

/// What the comment composer of a task held when it was last changed.
@immutable
final class CommentComposerDraft {
  const new({required this.text, this.mentions = const [], this.reply});

  final String text;
  final List<DraftMention> mentions;
  final DraftReply? reply;

  bool get isEmpty => text.trim().isEmpty && reply == null;

  @override
  bool operator ==(Object other) =>
      other is CommentComposerDraft &&
      other.text == text &&
      listEquals(other.mentions, mentions) &&
      other.reply == reply;

  @override
  int get hashCode => Object.hash(text, Object.hashAll(mentions), reply);

  @override
  String toString() => 'CommentComposerDraft(${text.length} characters)';
}

/// The unsent comment of each task, per account, so that nothing typed is
/// lost offline, after a failed send or when the app is ended: kept until
/// it is sent or emptied, and dropped with the account on sign-out. One
/// preferences entry per account holds the account's [maxDrafts] most
/// recently changed drafts.
final class CommentDrafts {
  new(this._store, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const maxDrafts = 50;

  static String keyFor(String account) => 'comment_drafts.$account';

  final PreferencesStore _store;
  final DateTime Function() _now;
  Future<void> _writes = Future.value();

  Future<CommentComposerDraft?> read({
    required String account,
    required int taskId,
  }) async {
    await _writes;
    return switch ((await _decoded(account))['$taskId']) {
      final Map<String, Object?> json => _draftOf(json),
      _ => null,
    };
  }

  /// An empty [draft] removes the task's.
  Future<void> save(
    CommentComposerDraft draft, {
    required String account,
    required int taskId,
  }) => _change(account, (drafts) {
    if (draft.isEmpty) {
      drafts.remove('$taskId');
      return;
    }
    drafts['$taskId'] = {
      'text': draft.text,
      'mentions': [
        for (final mention in draft.mentions)
          {
            'start': mention.start,
            'end': mention.end,
            'username': mention.username,
            'label': mention.label,
          },
      ],
      if (draft.reply case final reply?)
        'reply': {
          'comment_id': reply.commentId,
          'author': reply.author,
          'html': reply.html,
        },
      'saved_at': _now().toUtc().toIso8601String(),
    };
    _keepNewest(drafts);
  });

  Future<void> discard({required String account, required int taskId}) =>
      _change(account, (drafts) => drafts.remove('$taskId'));

  Future<void> discardAll(String account) {
    final done = _writes.then((_) => _store.remove(keyFor(account)));
    _writes = done.catchError((Object _) {});
    return done;
  }

  // One write at a time: each reads the entry the one before wrote.
  Future<void> _change(
    String account,
    void Function(Map<String, Object?> drafts) change,
  ) {
    final done = _writes.then((_) async {
      final drafts = await _decoded(account);
      change(drafts);
      if (drafts.isEmpty) {
        await _store.remove(keyFor(account));
      } else {
        await _store.setString(keyFor(account), jsonEncode(drafts));
      }
    });
    _writes = done.catchError((Object _) {});
    return done;
  }

  Future<Map<String, Object?>> _decoded(String account) async {
    final raw = await _store.getString(keyFor(account));
    if (raw == null) return {};
    try {
      return switch (jsonDecode(raw)) {
        final Map<String, Object?> map => map,
        _ => {},
      };
    } on FormatException {
      return {};
    }
  }

  static void _keepNewest(Map<String, Object?> drafts) {
    if (drafts.length <= maxDrafts) return;
    String savedAt(String key) => switch (drafts[key]) {
      {'saved_at': final String at} => at,
      _ => '',
    };
    final oldestFirst = drafts.keys.toList()
      ..sort((a, b) => savedAt(a).compareTo(savedAt(b)));
    oldestFirst.take(drafts.length - maxDrafts).toList().forEach(drafts.remove);
  }

  static CommentComposerDraft? _draftOf(Map<String, Object?> json) {
    final text = json['text'];
    if (text is! String) return null;
    final mentions = <DraftMention>[
      for (final mention in switch (json['mentions']) {
        final List<Object?> list => list,
        _ => const <Object?>[],
      })
        if (mention
            case {
              'start': final int start,
              'end': final int end,
              'username': final String username,
              'label': final String label,
            }
            when 0 <= start && start < end && end <= text.length)
          (start: start, end: end, username: username, label: label),
    ];
    final reply = switch (json['reply']) {
      {
        'comment_id': final int commentId,
        'author': final String author,
        'html': final String html,
      } =>
        (commentId: commentId, author: author, html: html),
      _ => null,
    };
    return CommentComposerDraft(text: text, mentions: mentions, reply: reply);
  }
}
