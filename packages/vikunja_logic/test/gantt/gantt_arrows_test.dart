import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

import '../helpers/tasks.dart';
import 'gantt_test_support.dart';

// ganttRelationArrows.spec.ts: positions in pixels (x, width) become
// anchors (start = x, end = x + width), in whatever unit; tasks have no
// dates.
GanttAnchor _anchor(int row, int x, int width) =>
    GanttAnchor(row: row, start: x, end: x + width);

void main() {
  test('RA1: no relation, no arrow', () {
    expect(
      ganttArrows(
        tasks: [task(1), task(2)],
        anchors: {1: _anchor(0, 0, 100), 2: _anchor(1, 50, 100)},
      ),
      isEmpty,
    );
  });

  test('RA2: blocking', () {
    expect(
      ganttArrows(
        tasks: [
          related(task(1), blocking: [2]),
          related(task(2), blocked: [1]),
        ],
        anchors: {1: _anchor(0, 0, 100), 2: _anchor(1, 150, 100)},
      ),
      [
        const GanttArrow(
          fromTaskId: 1,
          toTaskId: 2,
          kind: GanttArrowKind.blocking,
          fromRow: 0,
          toRow: 1,
          fromColumn: 100,
          toColumn: 150,
        ),
      ],
    );
  });

  test('RA3: precedes', () {
    final arrows = ganttArrows(
      tasks: [
        related(task(1), precedes: [2]),
        related(task(2), follows: [1]),
      ],
      anchors: {1: _anchor(0, 0, 100), 2: _anchor(1, 150, 100)},
    );

    expect(arrows, hasLength(1));
    expect(arrows.single.kind, GanttArrowKind.precedes);
  });

  test('RA4: a target without a bar draws nothing', () {
    expect(
      ganttArrows(
        tasks: [
          related(task(1), blocking: [99]),
        ],
        anchors: {1: _anchor(0, 0, 100)},
      ),
      isEmpty,
    );
  });

  test('RA5: a hidden target is replaced by its collapsed ancestor', () {
    final arrows = ganttArrows(
      tasks: [
        related(task(1), blocking: [3]),
        task(2),
        related(task(3), blocked: [1]),
      ],
      anchors: {1: _anchor(0, 0, 100), 2: _anchor(1, 50, 200)},
      hiddenToAncestor: {3: 2},
    );

    expect(arrows, hasLength(1));
    expect(arrows.single.toTaskId, 2);
    expect(arrows.single.toColumn, 50);
  });

  test('RA6: one arrow for both ends of a relation', () {
    expect(
      ganttArrows(
        tasks: [
          related(task(1), blocking: [2]),
          related(task(2), blocked: [1]),
        ],
        anchors: {1: _anchor(0, 0, 100), 2: _anchor(1, 150, 100)},
      ),
      hasLength(1),
    );
  });

  test('one arrow per kind for a pair, whichever way round', () {
    final arrows = ganttArrows(
      tasks: [
        related(task(1), blocking: [2], precedes: [2]),
        related(task(2), blocking: [1]),
      ],
      anchors: {1: _anchor(0, 0, 1), 2: _anchor(1, 3, 1)},
    );

    expect(
      [for (final arrow in arrows) (arrow.fromTaskId, arrow.kind)],
      [(1, GanttArrowKind.blocking), (1, GanttArrowKind.precedes)],
    );
  });

  test('an arrow that ends where it starts after rerouting is dropped', () {
    expect(
      ganttArrows(
        tasks: [
          related(task(2), blocking: [3]),
          task(3),
        ],
        anchors: {1: _anchor(0, 0, 1)},
        hiddenToAncestor: {2: 1, 3: 1},
      ),
      isEmpty,
    );
  });

  group('arrows sharing an end spread over at most 24 px', () {
    List<GanttArrow> fanOut(int count) => ganttArrows(
      tasks: [
        related(task(1), blocking: [for (var id = 2; id < count + 2; id++) id]),
        for (var id = 2; id < count + 2; id++) task(id),
      ],
      anchors: {
        for (var id = 1; id < count + 2; id++) id: _anchor(id - 1, id * 2, 1),
      },
    );

    test('one: centred', () {
      final arrow = fanOut(1).single;

      expect((arrow.fromOffset, arrow.toOffset), (0.0, 0.0));
    });

    test('three: 6 px apart', () {
      expect([for (final arrow in fanOut(3)) arrow.fromOffset], [-6, 0, 6]);
      expect([for (final arrow in fanOut(3)) arrow.toOffset], [0, 0, 0]);
    });

    test('five: 24 px', () {
      expect(
        [for (final arrow in fanOut(5)) arrow.fromOffset],
        [-12, -6, 0, 6, 12],
      );
    });

    test('seven: still 24 px, closer together', () {
      expect(
        [for (final arrow in fanOut(7)) arrow.fromOffset],
        [-12, -8, -4, 0, 4, 8, 12],
      );
    });

    test('by target too', () {
      final arrows = ganttArrows(
        tasks: [
          related(task(1), blocking: [3]),
          related(task(2), precedes: [3]),
          task(3),
        ],
        anchors: {
          1: _anchor(0, 0, 1),
          2: _anchor(1, 0, 1),
          3: _anchor(2, 5, 1),
        },
      );

      expect([for (final arrow in arrows) arrow.toOffset], [-3, 3]);
      expect([for (final arrow in arrows) arrow.fromOffset], [0, 0]);
    });
  });
}
