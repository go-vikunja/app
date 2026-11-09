import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/tasks/application/relation_search.dart';

import '../../helpers/sample_data.dart';

void main() {
  final self = sampleTask(id: 1, title: 'Plan the trip', identifier: 'W-1');
  final flights = sampleTask(id: 2, title: 'Book flights', identifier: 'W-2');
  final visa = sampleTask(id: 3, title: 'Get a visa', identifier: 'W-3');
  final suitcase = sampleTask(
    id: 4,
    title: 'Buy a suitcase',
    identifier: 'HOME-4',
    done: true,
  );
  const fresh = Task(id: -2, title: 'Fresh idea', projectId: 1);
  final task = self.copyWith(
    relatedTasks: {
      TaskRelationKind.related: [visa],
    },
  );
  final all = [self, flights, visa, suitcase, fresh];

  List<int> ids(
    String query, {
    TaskRelationKind kind = TaskRelationKind.related,
    bool includeDone = false,
    int limit = 50,
  }) => [
    for (final found in relationCandidates(
      all,
      task: task,
      kind: kind,
      query: query,
      includeDone: includeDone,
      limit: limit,
    ))
      found.id,
  ];

  test('leaves out the task itself, done tasks and existing relations of '
      'the kind', () {
    expect(ids(''), [2, -2]);
    expect(ids('', includeDone: true), [2, 4, -2]);
    expect(ids('', kind: TaskRelationKind.blocking), [2, 3, -2]);
  });

  test("a task's parent is not offered as its subtask, nor its subtask as "
      'its parent', () {
    final child = flights.copyWith(
      relatedTasks: {
        TaskRelationKind.parentTask: [self],
      },
    );
    final parent = self.copyWith(
      relatedTasks: {
        TaskRelationKind.subtask: [flights],
      },
    );
    List<int> candidates(Task of, TaskRelationKind kind) => [
      for (final found in relationCandidates(
        all,
        task: of,
        kind: kind,
        query: '',
        includeDone: false,
      ))
        found.id,
    ];

    expect(candidates(child, TaskRelationKind.subtask), [3, -2]);
    expect(candidates(child, TaskRelationKind.related), [1, 3, -2]);
    expect(candidates(parent, TaskRelationKind.parentTask), [3, -2]);
    expect(candidates(parent, TaskRelationKind.related), [2, 3, -2]);
  });

  test('matches the title and the identifier, ignoring case and blanks', () {
    expect(ids('  FLIGHTS '), [2]);
    expect(ids('home-4', includeDone: true), [4]);
    expect(ids('w-'), [2]);
    expect(ids('#'), isEmpty);
  });

  test('matches ignoring accents, in the query too', () {
    expect(ids('FLÏGHTS'), [2]);
    expect(
      [
        for (final found in relationCandidates(
          [...all, sampleTask(id: 5, title: 'Réserver l’hôtel')],
          task: task,
          kind: TaskRelationKind.related,
          query: 'reserver l’hotel',
          includeDone: false,
        ))
          found.id,
      ],
      [5],
    );
  });

  test('a task not yet synced is found by title only', () {
    expect(ids('fresh'), [-2]);
    expect(ids('#0'), isEmpty);
  });

  test('stops at the limit', () {
    expect(ids('', includeDone: true, limit: 2), [2, 4]);
  });

  test('server tasks come by id, then the queued ones as they were made', () {
    final ordered = inCreationOrder([
      const Task(id: -3, title: 'c', projectId: 1),
      const Task(id: 9, title: 'b', projectId: 1),
      const Task(id: -1, title: 'a', projectId: 1),
      const Task(id: 4, title: 'd', projectId: 1),
    ]);
    expect([for (final task in ordered) task.id], [4, 9, -1, -3]);
  });
}
