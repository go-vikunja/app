import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/description_editor/application/mention_suggestions.dart';

// testWidgets for its fake clock.
void main() {
  const jane = User(id: 1, username: 'jdoe', name: 'Jane Doe');
  const john = User(id: 2, username: 'john');
  const noUsername = User(id: 3, username: '', name: 'Ghost');

  testWidgets('the server is asked 300 ms after the last keystroke', (
    tester,
  ) async {
    final queries = <String>[];
    final controller = MentionController(
      search: (query) async {
        queries.add(query);
        return [jane, john];
      },
      known: () async => const [],
    );
    addTearDown(controller.dispose);

    controller.query('j');
    await tester.pump(const Duration(milliseconds: 200));
    controller.query('ja');
    expect(controller.value.active, isTrue);
    expect(controller.value.searching, isTrue);
    await tester.pump(const Duration(milliseconds: 299));
    expect(queries, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));

    expect(queries, ['ja']);
    expect(controller.value.people, [jane, john]);
    expect(controller.value.searching, isFalse);
    expect(controller.value.fromDevice, isFalse);
  });

  testWidgets('offline, the people this device knows stand in, filtered', (
    tester,
  ) async {
    final controller = MentionController(
      search: (query) async =>
          throw const NetworkFailure(NetworkProblem.unreachable),
      known: () async => [jane, john],
    );
    addTearDown(controller.dispose);

    controller.query('doe');
    await tester.pump(MentionController.debounce);

    expect(controller.value.people, [jane]);
    expect(controller.value.fromDevice, isTrue);
  });

  testWidgets('a slower answer to an earlier query never replaces a newer '
      'one', (tester) async {
    final answers = <String, Completer<List<User>>>{};
    final controller = MentionController(
      search: (query) => (answers[query] = Completer()).future,
      known: () async => const [],
    );
    addTearDown(controller.dispose);

    controller.query('j');
    await tester.pump(MentionController.debounce);
    controller.query('jo');
    await tester.pump(MentionController.debounce);
    answers['jo']!.complete([john]);
    await tester.pump();
    answers['j']!.complete([jane, john]);
    await tester.pump();

    expect(controller.value.query, 'jo');
    expect(controller.value.people, [john]);
  });

  testWidgets('the end of the mention hides the suggestions, also a late '
      'answer', (tester) async {
    final answer = Completer<List<User>>();
    final controller = MentionController(
      search: (query) => answer.future,
      known: () async => const [],
    );
    addTearDown(controller.dispose);

    controller.query('j');
    await tester.pump(MentionController.debounce);
    controller.end();
    answer.complete([jane]);
    await tester.pump();

    expect(controller.value.active, isFalse);
    expect(controller.value.people, isEmpty);
  });

  test('at most 10 people with a username, 5 for an empty query', () {
    final many = [
      for (var i = 1; i <= 12; i++) User(id: i, username: 'user$i'),
    ];
    expect(mentionable([noUsername, ...many], query: 'u'), many.take(10));
    expect(mentionable(many, query: ''), many.take(5));
    expect(mentionable([jane, jane], query: 'j'), [jane]);
  });
}
