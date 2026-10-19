import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

void main() {
  final monday = DateTime.utc(2026, 10, 12, 9);
  final friday = DateTime.utc(2026, 10, 16, 17);

  group('DateChange', () {
    test('set compares by instant, clear is a singleton', () {
      expect(DateChange.set(monday), SetDate(monday));
      expect(DateChange.set(monday), isNot(SetDate(friday)));
      expect(const DateChange.clear(), const ClearDate());
      expect(DateChange.set(monday), isNot(const ClearDate()));
      expect(DateChange.set(monday).hashCode, SetDate(monday).hashCode);
      expect(const ClearDate().hashCode, const ClearDate().hashCode);
    });
  });

  group('TaskChanges.isEmpty', () {
    test('is true without any field set', () {
      expect(const TaskChanges().isEmpty, isTrue);
    });

    test('is false with any single field set', () {
      final singles = [
        const TaskChanges(title: 't'),
        const TaskChanges(description: ''),
        const TaskChanges(done: false),
        const TaskChanges(isFavorite: false),
        const TaskChanges(priority: 0),
        const TaskChanges(percentDone: 0),
        const TaskChanges(hexColor: ''),
        TaskChanges(dueDate: DateChange.set(monday)),
        const TaskChanges(startDate: DateChange.clear()),
        const TaskChanges(endDate: DateChange.clear()),
        const TaskChanges(repeatAfter: Duration.zero),
        const TaskChanges(repeatMode: RepeatMode.afterAmount),
        const TaskChanges(projectId: 1),
        const TaskChanges(labels: IdSetChange(added: {1})),
        const TaskChanges(labels: IdSetChange(removed: {1})),
        const TaskChanges(assignees: IdSetChange(added: {1})),
        const TaskChanges(assignees: IdSetChange(removed: {1})),
        const TaskChanges(reminders: []),
        TaskChanges(
          relations: RelationChange(
            added: {const TaskRelationRef(TaskRelationKind.related, 1)},
          ),
        ),
        TaskChanges(
          relations: RelationChange(
            removed: {const TaskRelationRef(TaskRelationKind.related, 1)},
          ),
        ),
        const TaskChanges(kanban: {7: BucketPlacement(bucketId: 2)}),
        const TaskChanges(positions: {7: 1}),
      ];

      expect(singles.map((c) => c.isEmpty), everyElement(isFalse));
    });

    test('is true with empty id-set, relation, kanban and position '
        'changes', () {
      expect(
        const TaskChanges(
          labels: IdSetChange(),
          assignees: IdSetChange(),
          relations: RelationChange(),
          kanban: {},
          positions: {},
        ).isEmpty,
        isTrue,
      );
    });
  });

  group('TaskChanges.merge of kanban placements', () {
    const toDoing = BucketPlacement(bucketId: 2, position: 55);
    const toDone = BucketPlacement(bucketId: 3, position: 10);
    const otherView = BucketPlacement(bucketId: 20);
    const placedOnNewProject = TaskChanges(kanban: {9: toDone});

    test('per view, the later placement wins', () {
      const earlier = TaskChanges(kanban: {7: toDoing, 8: otherView});
      const later = TaskChanges(kanban: {7: toDone});

      expect(earlier.merge(later).kanban, {7: toDone, 8: otherView});
      expect(later.merge(earlier).kanban, {7: toDoing, 8: otherView});
    });

    test('a later placement without a position replaces one with it', () {
      const earlier = TaskChanges(kanban: {7: toDoing});
      const later = TaskChanges(kanban: {7: BucketPlacement(bucketId: 2)});

      expect(earlier.merge(later).kanban, {
        7: const BucketPlacement(bucketId: 2),
      });
    });

    test('a placement on one side only is kept', () {
      const placed = TaskChanges(kanban: {7: toDoing});

      expect(placed.merge(const TaskChanges(title: 'Renamed')).kanban, {
        7: toDoing,
      });
      expect(const TaskChanges(done: true).merge(placed).kanban, {7: toDoing});
      expect(
        const TaskChanges(done: true).merge(const TaskChanges()).kanban,
        isNull,
      );
    });

    test('a later done change drops a placement queued with the other done '
        'state, as its move would set it back', () {
      const intoDone = TaskChanges(done: true, kanban: {7: toDone});
      const outOfDone = TaskChanges(done: false, kanban: {7: toDoing});

      expect(
        intoDone.merge(const TaskChanges(done: false)),
        const TaskChanges(done: false),
      );
      expect(
        outOfDone.merge(const TaskChanges(done: true)),
        const TaskChanges(done: true),
      );
    });

    test('a later done change drops a placement queued without one', () {
      const placed = TaskChanges(kanban: {7: toDoing, 8: otherView});

      expect(
        placed.merge(const TaskChanges(done: true)),
        const TaskChanges(done: true),
      );
    });

    test('a later done change keeps only its own placements, so one on '
        "another view's done bucket cannot undo it", () {
      const intoDone = TaskChanges(done: true, kanban: {8: otherView});

      expect(
        const TaskChanges(done: false, kanban: {7: toDoing}).merge(intoDone),
        intoDone,
      );
    });

    test('a later change to the same done state keeps the placements', () {
      const intoDone = TaskChanges(done: true, kanban: {7: toDone});

      expect(intoDone.merge(const TaskChanges(done: true)), intoDone);
      expect(
        intoDone.merge(const TaskChanges(done: true, kanban: {8: otherView})),
        const TaskChanges(done: true, kanban: {7: toDone, 8: otherView}),
      );
    });

    test('a later project move drops the earlier placements', () {
      const placed = TaskChanges(kanban: {7: toDoing, 8: otherView});

      expect(
        placed.merge(const TaskChanges(projectId: 2)),
        const TaskChanges(projectId: 2),
      );
      expect(
        placed.merge(const TaskChanges(projectId: 2, kanban: {9: toDone})),
        const TaskChanges(projectId: 2, kanban: {9: toDone}),
      );
    });

    test('a placement after a project move is kept', () {
      expect(
        const TaskChanges(projectId: 2).merge(placedOnNewProject),
        const TaskChanges(projectId: 2, kanban: {9: toDone}),
      );
    });

    test('rides along with a done change', () {
      expect(
        const TaskChanges(done: true)
            .merge(const TaskChanges(kanban: {7: toDone})),
        const TaskChanges(done: true, kanban: {7: toDone}),
      );
    });
  });

  group('TaskChanges.merge of list positions', () {
    test('per view, the later position wins', () {
      const earlier = TaskChanges(positions: {7: 100, 8: 5});
      const later = TaskChanges(positions: {7: 50});

      expect(earlier.merge(later).positions, {7: 50, 8: 5});
      expect(later.merge(earlier).positions, {7: 100, 8: 5});
    });

    test('positions on one side only are kept', () {
      const placed = TaskChanges(positions: {7: 100});

      expect(placed.merge(const TaskChanges(title: 'Renamed')).positions, {
        7: 100,
      });
      expect(const TaskChanges(title: 'Renamed').merge(placed).positions, {
        7: 100,
      });
      expect(
        const TaskChanges(title: 'Renamed')
            .merge(const TaskChanges())
            .positions,
        isNull,
      );
    });

    test('a later done change keeps them', () {
      expect(
        const TaskChanges(
          done: false,
          positions: {7: 100},
        ).merge(const TaskChanges(done: true)),
        const TaskChanges(done: true, positions: {7: 100}),
      );
      expect(
        const TaskChanges(positions: {7: 100})
            .merge(const TaskChanges(done: true, positions: {8: 5})),
        const TaskChanges(done: true, positions: {7: 100, 8: 5}),
      );
    });

    test('a later project move drops the earlier positions', () {
      const placed = TaskChanges(positions: {7: 100, 8: 5});

      expect(
        placed.merge(const TaskChanges(projectId: 2)),
        const TaskChanges(projectId: 2),
      );
      expect(
        placed.merge(const TaskChanges(projectId: 2, positions: {9: 1})),
        const TaskChanges(projectId: 2, positions: {9: 1}),
      );
    });

    test('positions after a project move are kept', () {
      expect(
        const TaskChanges(projectId: 2)
            .merge(const TaskChanges(positions: {9: 1})),
        const TaskChanges(projectId: 2, positions: {9: 1}),
      );
    });

    test('merge independently of kanban placements', () {
      const placement = BucketPlacement(bucketId: 2, position: 55);

      expect(
        const TaskChanges(kanban: {7: placement})
            .merge(const TaskChanges(positions: {8: 3})),
        const TaskChanges(kanban: {7: placement}, positions: {8: 3}),
      );
      expect(
        const TaskChanges(
          kanban: {7: placement},
          positions: {8: 3},
        ).merge(const TaskChanges(done: true)),
        const TaskChanges(done: true, positions: {8: 3}),
      );
    });
  });

  group('TaskChanges.merge', () {
    test('the later change wins where both set a field', () {
      final earlier = TaskChanges(
        title: 'old',
        done: true,
        priority: 1,
        dueDate: DateChange.set(monday),
      );
      final later = TaskChanges(
        title: 'new',
        done: false,
        dueDate: DateChange.set(friday),
      );

      expect(
        earlier.merge(later),
        TaskChanges(
          title: 'new',
          done: false,
          priority: 1,
          dueDate: DateChange.set(friday),
        ),
      );
    });

    test('fields the later change leaves null keep the earlier value', () {
      final earlier = TaskChanges(
        description: '<p>d</p>',
        isFavorite: true,
        percentDone: 0.5,
        hexColor: 'ff00aa',
        startDate: DateChange.set(monday),
        endDate: const DateChange.clear(),
      );

      expect(
        earlier.merge(const TaskChanges(done: true)),
        TaskChanges(
          description: '<p>d</p>',
          done: true,
          isFavorite: true,
          percentDone: 0.5,
          hexColor: 'ff00aa',
          startDate: DateChange.set(monday),
          endDate: const DateChange.clear(),
        ),
      );
      expect(earlier.merge(const TaskChanges()), earlier);
      expect(const TaskChanges().merge(earlier), earlier);
    });

    test('a clear after a set clears, a set after a clear sets', () {
      final set = TaskChanges(dueDate: DateChange.set(monday));
      const clear = TaskChanges(dueDate: DateChange.clear());

      expect(set.merge(clear).dueDate, const ClearDate());
      expect(clear.merge(set).dueDate, SetDate(monday));
    });

    test('a toggle and its undo leave the last state', () {
      const done = TaskChanges(done: true);
      const undone = TaskChanges(done: false);

      expect(done.merge(undone), undone);
      expect(done.merge(undone).merge(done), done);
    });

    test('repeat and project follow the later change', () {
      const repeating = TaskChanges(
        repeatAfter: Duration(days: 30),
        repeatMode: RepeatMode.afterAmount,
        projectId: 3,
      );
      const removed = TaskChanges(
        repeatAfter: Duration.zero,
        repeatMode: RepeatMode.afterAmount,
      );

      expect(
        repeating.merge(removed),
        const TaskChanges(
          repeatAfter: Duration.zero,
          repeatMode: RepeatMode.afterAmount,
          projectId: 3,
        ),
      );
      expect(removed.merge(repeating), repeating);
      expect(repeating.merge(const TaskChanges(projectId: 4)).projectId, 4);
      expect(
        repeating.merge(const TaskChanges(repeatMode: RepeatMode.monthly)),
        const TaskChanges(
          repeatAfter: Duration(days: 30),
          repeatMode: RepeatMode.monthly,
          projectId: 3,
        ),
      );
    });
  });

  group('TaskChanges.merge of labels, assignees and reminders', () {
    final morning = TaskReminder(reminder: monday);
    const hourBefore = TaskReminder(
      relativePeriod: Duration(hours: -1),
      relativeTo: ReminderRelativeTo.dueDate,
    );

    test('id-set changes merge per id, the later one winning', () {
      const earlier = TaskChanges(
        labels: IdSetChange(added: {1, 2}),
        assignees: IdSetChange(removed: {7}),
      );
      const later = TaskChanges(
        labels: IdSetChange(removed: {2}),
        assignees: IdSetChange(added: {7, 8}),
      );

      expect(
        earlier.merge(later),
        const TaskChanges(
          labels: IdSetChange(added: {1}, removed: {2}),
          assignees: IdSetChange(added: {7, 8}),
        ),
      );
    });

    test('a label added, then removed, then added again stays added', () {
      final merged = const TaskChanges(labels: IdSetChange(added: {1}))
          .merge(const TaskChanges(labels: IdSetChange(removed: {1})))
          .merge(const TaskChanges(labels: IdSetChange(added: {1})));

      expect(merged.labels, const IdSetChange(added: {1}));
    });

    test('an id-set change on one side only is kept', () {
      const labels = TaskChanges(labels: IdSetChange(added: {1}));
      const assignees = TaskChanges(assignees: IdSetChange(removed: {7}));

      expect(
        labels.merge(assignees),
        const TaskChanges(
          labels: IdSetChange(added: {1}),
          assignees: IdSetChange(removed: {7}),
        ),
      );
      expect(labels.merge(const TaskChanges(title: 't')).labels, labels.labels);
      expect(const TaskChanges(title: 't').merge(labels).labels, labels.labels);
    });

    test('reminders are a whole list: the later one replaces it', () {
      final earlier = TaskChanges(reminders: [morning, hourBefore]);
      const later = TaskChanges(reminders: [hourBefore]);

      expect(earlier.merge(later).reminders, [hourBefore]);
      expect(
        earlier.merge(const TaskChanges(reminders: [])).reminders,
        isEmpty,
      );
      expect(earlier.merge(const TaskChanges(title: 't')).reminders, [
        morning,
        hourBefore,
      ]);
      expect(const TaskChanges().merge(earlier).reminders, earlier.reminders);
    });

    test('an add and its removal merge into a change with an empty side, '
        'which is not empty as a whole', () {
      final merged = const TaskChanges(labels: IdSetChange(added: {1}))
          .merge(const TaskChanges(labels: IdSetChange(removed: {1})));

      expect(merged.isEmpty, isFalse);
      expect(merged.labels, const IdSetChange(removed: {1}));
    });
  });

  group('TaskChanges.merge of relations', () {
    const parent = TaskRelationRef(TaskRelationKind.parentTask, 1);
    const blocks = TaskRelationRef(TaskRelationKind.blocking, 2);

    test('merge per edge, the later change winning', () {
      final earlier = TaskChanges(
        relations: RelationChange(added: {parent, blocks}),
      );
      final later = TaskChanges(relations: RelationChange(removed: {blocks}));

      expect(
        earlier.merge(later),
        TaskChanges(
          relations: RelationChange(added: {parent}, removed: {blocks}),
        ),
      );
    });

    test('a relation change on one side only is kept', () {
      final relations = TaskChanges(relations: RelationChange(added: {parent}));

      expect(
        relations.merge(const TaskChanges(title: 't')).relations,
        relations.relations,
      );
      expect(
        const TaskChanges(title: 't').merge(relations).relations,
        relations.relations,
      );
      expect(const TaskChanges().merge(const TaskChanges()).relations, isNull);
    });
  });

  group('equality', () {
    test('compares relation changes by content', () {
      const one = TaskRelationRef(TaskRelationKind.related, 1);
      const two = TaskRelationRef(TaskRelationKind.related, 2);

      expect(
        TaskChanges(relations: RelationChange(added: {one, two})),
        TaskChanges(relations: RelationChange(added: {two, one})),
      );
      expect(
        TaskChanges(relations: RelationChange(added: {one, two})).hashCode,
        TaskChanges(relations: RelationChange(added: {two, one})).hashCode,
      );
      expect(
        TaskChanges(relations: RelationChange(added: {one})),
        isNot(TaskChanges(relations: RelationChange(removed: {one}))),
      );
      expect(
        TaskChanges(relations: RelationChange(added: {one})),
        isNot(const TaskChanges()),
      );
    });

    test('compares every field', () {
      expect(
        TaskChanges(title: 'a', dueDate: DateChange.set(monday)),
        TaskChanges(title: 'a', dueDate: DateChange.set(monday)),
      );
      expect(
        TaskChanges(title: 'a', dueDate: DateChange.set(monday)).hashCode,
        TaskChanges(title: 'a', dueDate: DateChange.set(monday)).hashCode,
      );
      expect(
        const TaskChanges(title: 'a'),
        isNot(const TaskChanges(title: 'a', done: true)),
      );
      expect(
        const TaskChanges(percentDone: 0.5),
        isNot(const TaskChanges(percentDone: 0.25)),
      );
      expect(
        const TaskChanges(repeatAfter: Duration(days: 1)),
        isNot(const TaskChanges(repeatAfter: Duration(days: 2))),
      );
      expect(
        const TaskChanges(repeatMode: RepeatMode.monthly),
        isNot(const TaskChanges(repeatMode: RepeatMode.afterAmount)),
      );
      expect(
        const TaskChanges(projectId: 1),
        isNot(const TaskChanges(projectId: 2)),
      );
    });

    test('compares id-set changes by content', () {
      expect(
        const TaskChanges(labels: IdSetChange(added: {1, 2})),
        const TaskChanges(labels: IdSetChange(added: {2, 1})),
      );
      expect(
        const TaskChanges(labels: IdSetChange(added: {1, 2})).hashCode,
        const TaskChanges(labels: IdSetChange(added: {2, 1})).hashCode,
      );
      expect(
        const TaskChanges(labels: IdSetChange(added: {1})),
        isNot(const TaskChanges(assignees: IdSetChange(added: {1}))),
      );
      expect(
        const TaskChanges(labels: IdSetChange(added: {1})),
        isNot(const TaskChanges(labels: IdSetChange(removed: {1}))),
      );
    });

    test('compares kanban placements per view, in any order', () {
      const a = BucketPlacement(bucketId: 2, position: 55);
      const b = BucketPlacement(bucketId: 20);

      expect(
        const TaskChanges(kanban: {7: a, 8: b}),
        const TaskChanges(kanban: {8: b, 7: a}),
      );
      expect(
        const TaskChanges(kanban: {7: a, 8: b}).hashCode,
        const TaskChanges(kanban: {8: b, 7: a}).hashCode,
      );
      expect(
        const TaskChanges(kanban: {7: a}),
        isNot(const TaskChanges(kanban: {8: a})),
      );
      expect(
        const TaskChanges(kanban: {7: a}),
        isNot(const TaskChanges(kanban: {7: b})),
      );
      expect(
        const TaskChanges(kanban: {7: a}),
        isNot(const TaskChanges(kanban: {7: a, 8: b})),
      );
      expect(const TaskChanges(kanban: {}), isNot(const TaskChanges()));
    });

    test('compares list positions per view, in any order', () {
      expect(
        const TaskChanges(positions: {7: 1, 8: 2}),
        const TaskChanges(positions: {8: 2, 7: 1}),
      );
      expect(
        const TaskChanges(positions: {7: 1, 8: 2}).hashCode,
        const TaskChanges(positions: {8: 2, 7: 1}).hashCode,
      );
      expect(
        const TaskChanges(positions: {7: 1}),
        isNot(const TaskChanges(positions: {8: 1})),
      );
      expect(
        const TaskChanges(positions: {7: 1}),
        isNot(const TaskChanges(positions: {7: 2})),
      );
      expect(
        const TaskChanges(positions: {7: 1}),
        isNot(const TaskChanges(positions: {7: 1, 8: 2})),
      );
      expect(const TaskChanges(positions: {}), isNot(const TaskChanges()));
      expect(
        const TaskChanges(positions: {7: 1}),
        isNot(const TaskChanges(kanban: {7: BucketPlacement(bucketId: 1)})),
      );
    });

    test('compares reminders element by element', () {
      final morning = TaskReminder(reminder: monday);
      const hourBefore = TaskReminder(
        relativePeriod: Duration(hours: -1),
        relativeTo: ReminderRelativeTo.dueDate,
      );

      expect(
        TaskChanges(reminders: [morning, hourBefore]),
        TaskChanges(
          reminders: [
            TaskReminder(reminder: monday),
            hourBefore,
          ],
        ),
      );
      expect(
        TaskChanges(reminders: [morning, hourBefore]).hashCode,
        TaskChanges(
          reminders: [
            TaskReminder(reminder: monday),
            hourBefore,
          ],
        ).hashCode,
      );
      expect(
        TaskChanges(reminders: [morning]),
        isNot(TaskChanges(reminders: [TaskReminder(reminder: friday)])),
      );
      expect(
        TaskChanges(reminders: [morning]),
        isNot(TaskChanges(reminders: [morning, morning])),
      );
      expect(const TaskChanges(reminders: []), isNot(const TaskChanges()));
      expect(
        const TaskChanges(reminders: []),
        const TaskChanges(reminders: []),
      );
    });
  });

  group('toString', () {
    test('names the fields set without their user text', () {
      final text = TaskChanges(
        title: 'Secret plan',
        description: '<p>Hidden</p>',
        done: true,
        dueDate: DateChange.set(monday),
        kanban: const {7: BucketPlacement(bucketId: 2, position: 55)},
        positions: const {8: 12.5},
      ).toString();

      expect(text, isNot(contains('Secret')));
      expect(text, isNot(contains('Hidden')));
      expect(text, contains('title'));
      expect(text, contains('done: true'));
      expect(text, contains('BucketPlacement(2, 55.0)'));
      expect(text, contains('positions: {8: 12.5}'));
    });

    test('is short without any field', () {
      expect(const TaskChanges().toString(), 'TaskChanges()');
    });
  });
}
