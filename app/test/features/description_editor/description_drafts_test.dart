import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/features/description_editor/application/description_drafts.dart';
import 'package:vikunja_mobile/features/description_editor/application/description_target.dart';

import '../../helpers/auth_fakes.dart';

void main() {
  late MemoryPreferencesStore store;
  late DescriptionDrafts drafts;
  const task = TaskDescriptionTarget(1);
  const draft = DescriptionDraft(html: '<p>Draft</p>', base: '<p>Base</p>');

  setUp(() {
    store = MemoryPreferencesStore();
    drafts = DescriptionDrafts(store);
  });

  List<Object?> stored() => switch (store.values[DescriptionDrafts.key]) {
    final String raw => jsonDecode(raw) as List<Object?>,
    _ => const [],
  };

  test('a draft comes back for its account and description only', () async {
    await drafts.save(draft, account: 'a', target: task);

    final read = await drafts.read(account: 'a', target: task);
    expect((read?.html, read?.base), ('<p>Draft</p>', '<p>Base</p>'));
    expect(await drafts.read(account: 'b', target: task), isNull);
    expect(
      await drafts.read(account: 'a', target: const TaskDescriptionTarget(2)),
      isNull,
    );
    expect(
      await drafts.read(
        account: 'a',
        target: const ProjectDescriptionTarget(1),
      ),
      isNull,
    );
  });

  test("a draft under a task's temporary id is found by its server id, "
      'and the other way round, once the create was answered', () async {
    final remaps = {-3: 42};
    final asked = <int>[];
    Future<int> resolve(int id) async {
      asked.add(id);
      return remaps[id] ?? id;
    }

    const server = TaskDescriptionTarget(42);
    await drafts.save(
      draft,
      account: 'a',
      target: const TaskDescriptionTarget(-3),
    );

    expect(await drafts.read(account: 'a', target: server), isNull);
    expect(
      (await drafts.read(
        account: 'a',
        target: server,
        resolveId: resolve,
      ))?.html,
      '<p>Draft</p>',
    );
    expect(asked, [-3]);
    for (final other in const [
      TaskDescriptionTarget(43),
      TaskDescriptionTarget(-4),
    ]) {
      expect(
        await drafts.read(account: 'a', target: other, resolveId: resolve),
        isNull,
      );
    }
    expect(
      await drafts.read(account: 'b', target: server, resolveId: resolve),
      isNull,
    );
    expect(
      await drafts.read(
        account: 'a',
        target: const ProjectDescriptionTarget(42),
        resolveId: resolve,
      ),
      isNull,
    );

    await drafts.discard(account: 'a', target: server);
    expect(store.values, isNotEmpty);
    await drafts.discard(account: 'a', target: server, resolveId: resolve);
    expect(store.values, isEmpty);

    await drafts.save(draft, account: 'a', target: server);
    expect(
      await drafts.read(
        account: 'a',
        target: const TaskDescriptionTarget(-3),
        resolveId: resolve,
      ),
      isNotNull,
    );
    asked.clear();
    await drafts.read(
      account: 'a',
      target: const TaskDescriptionTarget(7),
      resolveId: resolve,
    );
    expect(asked, isEmpty, reason: 'two server ids need no lookup');
  });

  test("a draft under a label's temporary id is found by its server id once "
      'the create was answered, and goes with it', () async {
    Future<int> resolve(int id) async => id == -1 ? 42 : id;
    await drafts.save(
      draft,
      account: 'a',
      target: const LabelDescriptionTarget(-1),
    );

    expect(
      (await drafts.read(
        account: 'a',
        target: const LabelDescriptionTarget(42),
        resolveId: resolve,
      ))?.html,
      '<p>Draft</p>',
    );
    for (final other in const <DescriptionTarget>[
      TaskDescriptionTarget(42),
      LabelDescriptionTarget(43),
    ]) {
      expect(
        await drafts.read(account: 'a', target: other, resolveId: resolve),
        isNull,
      );
    }

    await drafts.discard(
      account: 'a',
      target: const LabelDescriptionTarget(42),
      resolveId: resolve,
    );
    expect(store.values, isEmpty);
  });

  test('saved under the server id, the draft replaces the one under the '
      "task's temporary id", () async {
    Future<int> resolve(int id) async => id == -3 ? 42 : id;
    await drafts.save(
      draft,
      account: 'a',
      target: const TaskDescriptionTarget(-3),
    );

    await drafts.save(
      const DescriptionDraft(html: '<p>Newer</p>', base: '<p>Base</p>'),
      account: 'a',
      target: const TaskDescriptionTarget(42),
      resolveId: resolve,
    );

    expect(stored(), [
      {
        'account': 'a',
        'target': 'task:42',
        'html': '<p>Newer</p>',
        'base': '<p>Base</p>',
      },
    ]);
  });

  testWidgets('a lookup that does not answer counts as no match, and the '
      'writes after it still go', (tester) async {
    // Made in the test's fake time, whose timers this test moves on.
    final drafts = DescriptionDrafts(store);
    final never = Completer<int>();
    await drafts.save(
      draft,
      account: 'a',
      target: const TaskDescriptionTarget(-3),
    );
    var read = false;
    DescriptionDraft? found;
    var saved = false;
    unawaited(
      drafts
          .read(
            account: 'a',
            target: const TaskDescriptionTarget(42),
            resolveId: (_) => never.future,
          )
          .then((draft) {
            read = true;
            found = draft;
          }),
    );
    unawaited(
      drafts.discard(
        account: 'a',
        target: const TaskDescriptionTarget(42),
        resolveId: (_) => never.future,
      ),
    );
    unawaited(
      drafts.save(draft, account: 'a', target: task).then((_) => saved = true),
    );

    await tester.pump(const Duration(seconds: 3));

    expect(read, isTrue);
    expect(found, isNull);
    expect(saved, isTrue);
    expect(
      [for (final entry in stored()) (entry! as Map)['target']],
      ['task:-3', 'task:1'],
    );
  });

  test('one draft per account and description, so a draft for another '
      'description stays', () async {
    await drafts.save(draft, account: 'a', target: task);
    await drafts.save(
      const DescriptionDraft(html: '<p>Other</p>', base: ''),
      account: 'a',
      target: const ProjectDescriptionTarget(3),
    );
    await drafts.save(
      const DescriptionDraft(html: '<p>Bob</p>', base: ''),
      account: 'b',
      target: task,
    );

    expect(
      (await drafts.read(account: 'a', target: task))?.html,
      '<p>Draft</p>',
    );
    expect(
      (await drafts.read(
        account: 'a',
        target: const ProjectDescriptionTarget(3),
      ))?.html,
      '<p>Other</p>',
    );
    expect((await drafts.read(account: 'b', target: task))?.html, '<p>Bob</p>');

    await drafts.save(
      const DescriptionDraft(html: '<p>Newer</p>', base: ''),
      account: 'a',
      target: task,
    );
    expect(
      (await drafts.read(account: 'a', target: task))?.html,
      '<p>Newer</p>',
    );
    expect(stored(), hasLength(3));
  });

  test('at most ${DescriptionDrafts.maxDrafts} in all: the one saved longest '
      'ago goes first', () async {
    for (var id = 1; id <= DescriptionDrafts.maxDrafts; id++) {
      await drafts.save(
        draft,
        account: id.isEven ? 'a' : 'b',
        target: TaskDescriptionTarget(id),
      );
    }
    // Saved again, the first is now the newest.
    await drafts.save(draft, account: 'b', target: task);

    await drafts.save(
      draft,
      account: 'a',
      target: const ProjectDescriptionTarget(1),
    );

    expect(stored(), hasLength(DescriptionDrafts.maxDrafts));
    expect(await drafts.read(account: 'b', target: task), isNotNull);
    expect(
      await drafts.read(account: 'a', target: const TaskDescriptionTarget(2)),
      isNull,
    );
    expect(
      await drafts.read(account: 'b', target: const TaskDescriptionTarget(3)),
      isNotNull,
    );
  });

  test('writes go one after the other, so none is lost', () async {
    await Future.wait([
      drafts.save(draft, account: 'a', target: task),
      drafts.save(
        draft,
        account: 'a',
        target: const ProjectDescriptionTarget(3),
      ),
      drafts.save(draft, account: 'b', target: task),
      drafts.discard(account: 'a', target: const ProjectDescriptionTarget(3)),
    ]);

    expect(await drafts.read(account: 'a', target: task), isNotNull);
    expect(await drafts.read(account: 'b', target: task), isNotNull);
    expect(stored(), hasLength(2));
  });

  test("discard removes only that description's draft", () async {
    await drafts.save(draft, account: 'a', target: task);
    await drafts.save(draft, account: 'b', target: task);

    await drafts.discard(account: 'a', target: const TaskDescriptionTarget(2));
    expect(await drafts.read(account: 'a', target: task), isNotNull);

    await drafts.discard(account: 'a', target: task);
    expect(await drafts.read(account: 'a', target: task), isNull);
    expect(await drafts.read(account: 'b', target: task), isNotNull);

    await drafts.discard(account: 'b', target: task);
    expect(store.values, isEmpty);
  });

  test("discardAll removes only the account's drafts", () async {
    await drafts.save(draft, account: 'a', target: task);
    await drafts.save(
      draft,
      account: 'a',
      target: const ProjectDescriptionTarget(3),
    );
    await drafts.save(draft, account: 'b', target: task);

    await drafts.discardAll('a');
    expect(await drafts.read(account: 'a', target: task), isNull);
    expect(
      await drafts.read(
        account: 'a',
        target: const ProjectDescriptionTarget(3),
      ),
      isNull,
    );
    expect(await drafts.read(account: 'b', target: task), isNotNull);

    await drafts.discardAll('b');
    expect(store.values, isEmpty);
  });

  test('discardAll removes a stored value that names no account', () async {
    for (final value in [
      'not json',
      '{}',
      '[3]',
      '[{"account":5,"target":"task:1","html":"","base":""}]',
    ]) {
      store.values[DescriptionDrafts.key] = value;

      await drafts.discardAll('a');

      expect(store.values, isEmpty, reason: value);
    }
  });

  test('a stored value that is not a draft reads as none', () async {
    store.values[DescriptionDrafts.key] = 'not json';
    expect(await drafts.read(account: 'a', target: task), isNull);

    store.values[DescriptionDrafts.key] =
        '[{"account":"a","target":"task:1","html":3}]';
    expect(await drafts.read(account: 'a', target: task), isNull);
  });

  test("development builds' drafts in the preferences, which iOS backs up, "
      'are removed once seen and not offered', () async {
    final preferences = MemoryPreferencesStore()
      ..values['description_editor.draft'] = jsonEncode({
        'account': 'a',
        'target': 'task:1',
        'html': '<p>Old</p>',
        'base': '',
      })
      ..values['description_editor.drafts'] = jsonEncode([
        {'account': 'a', 'target': 'task:1', 'html': '<p>Old</p>', 'base': ''},
      ])
      ..values['other'] = 'kept';
    drafts = DescriptionDrafts(store, legacy: preferences);

    expect(await drafts.read(account: 'a', target: task), isNull);
    expect(preferences.values, {'other': 'kept'});
    expect(store.values, isEmpty);

    await drafts.save(draft, account: 'a', target: task);
    expect(preferences.values, {'other': 'kept'});
    expect(store.values.keys, [DescriptionDrafts.key]);
  });

  test('old drafts that cannot be removed now are removed later, and keep '
      'nothing from working', () async {
    final preferences = MemoryPreferencesStore()
      ..values[DescriptionDrafts.key] = '[]'
      ..failNextRead.add(DescriptionDrafts.key);
    drafts = DescriptionDrafts(store, legacy: preferences);

    await drafts.save(draft, account: 'a', target: task);
    expect(preferences.values, isNotEmpty);
    expect(await drafts.read(account: 'a', target: task), isNotNull);

    expect(preferences.values, isEmpty);
  });
}
