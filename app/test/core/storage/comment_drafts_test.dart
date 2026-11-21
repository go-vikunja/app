import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/storage/comment_drafts.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';

import '../../helpers/auth_fakes.dart';

void main() {
  late MemoryPreferencesStore store;
  late DateTime now;
  late CommentDrafts drafts;

  const reply = (commentId: 4, author: 'Anna', html: '<p>Looks good</p>');
  const draft = CommentComposerDraft(
    text: 'Thanks @Bob, done',
    mentions: [(start: 7, end: 11, username: 'bob', label: 'Bob')],
    reply: reply,
  );

  setUp(() {
    store = MemoryPreferencesStore();
    now = DateTime.utc(2026, 10, 21, 12);
    drafts = CommentDrafts(store, now: () => now);
  });

  test('a draft comes back per account and task, with its mentions and '
      'the comment it replies to', () async {
    await drafts.save(draft, account: 'a', taskId: 3);
    await drafts.save(
      const CommentComposerDraft(text: 'Other task'),
      account: 'a',
      taskId: 4,
    );

    expect(await drafts.read(account: 'a', taskId: 3), draft);
    expect(
      await CommentDrafts(store).read(account: 'a', taskId: 3),
      draft,
      reason: 'it outlives the app',
    );
    expect((await drafts.read(account: 'a', taskId: 4))!.text, 'Other task');
    expect(await drafts.read(account: 'a', taskId: 5), isNull);
    expect(await drafts.read(account: 'b', taskId: 3), isNull);
    expect(store.values.keys, [CommentDrafts.keyFor('a')]);
  });

  test('sending or emptying the composer removes it; the last one removes '
      "the account's entry", () async {
    await drafts.save(draft, account: 'a', taskId: 3);
    await drafts.save(draft, account: 'a', taskId: 4);

    await drafts.discard(account: 'a', taskId: 3);
    await drafts.save(
      const CommentComposerDraft(text: '  \n'),
      account: 'a',
      taskId: 4,
    );

    expect(await drafts.read(account: 'a', taskId: 3), isNull);
    expect(await drafts.read(account: 'a', taskId: 4), isNull);
    expect(store.values, isEmpty);
  });

  test('a reply without text yet is kept', () async {
    const replying = CommentComposerDraft(text: '', reply: reply);

    await drafts.save(replying, account: 'a', taskId: 3);

    expect(await drafts.read(account: 'a', taskId: 3), replying);
  });

  test('signing out drops every draft of the account only', () async {
    await drafts.save(draft, account: 'a', taskId: 3);
    await drafts.save(draft, account: 'b', taskId: 3);

    await drafts.discardAll('a');

    expect(await drafts.read(account: 'a', taskId: 3), isNull);
    expect(await drafts.read(account: 'b', taskId: 3), draft);
  });

  test('writes in a row each build on the one before', () async {
    await Future.wait([
      for (var task = 1; task <= 5; task++)
        drafts.save(
          CommentComposerDraft(text: 'Draft $task'),
          account: 'a',
          taskId: task,
        ),
      drafts.discard(account: 'a', taskId: 2),
    ]);

    for (final task in [1, 3, 4, 5]) {
      expect(
        (await drafts.read(account: 'a', taskId: task))!.text,
        'Draft $task',
      );
    }
    expect(await drafts.read(account: 'a', taskId: 2), isNull);
  });

  test('the most recently changed ones stay when there are too '
      'many', () async {
    for (var task = 1; task <= CommentDrafts.maxDrafts + 2; task++) {
      now = now.add(const Duration(minutes: 1));
      await drafts.save(
        CommentComposerDraft(text: 'Draft $task'),
        account: 'a',
        taskId: task,
      );
    }
    now = now.add(const Duration(minutes: 1));
    await drafts.save(
      const CommentComposerDraft(text: 'Draft 1 again'),
      account: 'b',
      taskId: 1,
    );

    expect(await drafts.read(account: 'a', taskId: 1), isNull);
    expect(await drafts.read(account: 'a', taskId: 2), isNull);
    expect((await drafts.read(account: 'a', taskId: 3))!.text, 'Draft 3');
    expect(
      (await drafts.read(
        account: 'a',
        taskId: CommentDrafts.maxDrafts + 2,
      ))!.text,
      'Draft ${CommentDrafts.maxDrafts + 2}',
    );
  });

  test('an unreadable entry or mention reads as no draft or no '
      'mention', () async {
    store.values[CommentDrafts.keyFor('a')] = '{not json';
    expect(await drafts.read(account: 'a', taskId: 3), isNull);

    store.values[CommentDrafts.keyFor('a')] = jsonEncode({
      '3': {
        'text': 'Hi @Bob',
        'mentions': [
          {'start': 3, 'end': 7, 'username': 'bob', 'label': 'Bob'},
          {'start': 5, 'end': 40, 'username': 'x', 'label': 'X'},
          {'start': '3'},
        ],
        'reply': {'comment_id': '4'},
      },
      '4': {'mentions': <Object>[]},
    });
    expect(
      await drafts.read(account: 'a', taskId: 3),
      const CommentComposerDraft(
        text: 'Hi @Bob',
        mentions: [(start: 3, end: 7, username: 'bob', label: 'Bob')],
      ),
    );
    expect(await drafts.read(account: 'a', taskId: 4), isNull);

    await drafts.save(draft, account: 'a', taskId: 5);
    expect(await drafts.read(account: 'a', taskId: 5), draft);
  });

  test('a failed write fails its caller only', () async {
    final failing = _FailingOnce(store);
    drafts = CommentDrafts(failing, now: () => now);

    await expectLater(
      drafts.save(draft, account: 'a', taskId: 3),
      throwsA(isA<StateError>()),
    );
    await drafts.save(draft, account: 'a', taskId: 4);

    expect(await drafts.read(account: 'a', taskId: 4), draft);
  });
}

final class _FailingOnce implements PreferencesStore {
  new(this._inner);

  final MemoryPreferencesStore _inner;
  var _failed = false;

  @override
  Future<String?> getString(String key) => _inner.getString(key);

  @override
  Future<void> setString(String key, String value) async {
    if (!_failed) {
      _failed = true;
      throw StateError('disk full');
    }
    await _inner.setString(key, value);
  }

  @override
  Future<void> remove(String key) => _inner.remove(key);
}
