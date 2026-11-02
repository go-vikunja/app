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

  test('one slot: a newer draft replaces the older', () async {
    await drafts.save(draft, account: 'a', target: task);
    await drafts.save(
      const DescriptionDraft(html: '<p>Other</p>', base: ''),
      account: 'a',
      target: const ProjectDescriptionTarget(3),
    );

    expect(await drafts.read(account: 'a', target: task), isNull);
  });

  test("discard removes only that description's draft", () async {
    await drafts.save(draft, account: 'a', target: task);

    await drafts.discard(account: 'a', target: const TaskDescriptionTarget(2));
    expect(await drafts.read(account: 'a', target: task), isNotNull);

    await drafts.discard(account: 'a', target: task);
    expect(store.values, isEmpty);
  });

  test("discardAll removes only the account's draft", () async {
    await drafts.save(draft, account: 'a', target: task);

    await drafts.discardAll('b');
    expect(await drafts.read(account: 'a', target: task), isNotNull);

    await drafts.discardAll('a');
    expect(store.values, isEmpty);
  });

  test('discardAll removes a stored value that names no account', () async {
    for (final value in ['not json', '{}', '{"account":5}']) {
      store.values[DescriptionDrafts.key] = value;

      await drafts.discardAll('a');

      expect(store.values, isEmpty, reason: value);
    }
  });

  test('a stored value that is not a draft reads as none', () async {
    store.values[DescriptionDrafts.key] = 'not json';
    expect(await drafts.read(account: 'a', target: task), isNull);

    store.values[DescriptionDrafts.key] =
        '{"account":"a","target":"task:1","html":3}';
    expect(await drafts.read(account: 'a', target: task), isNull);
  });
}
