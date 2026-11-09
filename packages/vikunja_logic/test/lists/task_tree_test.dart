import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

import '../helpers/tasks.dart';

bool _showsAtTopLevel(Task task, List<int> idsInView) => showsAtTopLevel(
  task.parentTasks.map((parent) => parent.id),
  idsInView.toSet(),
);

/// The tree as `id(child, …)`, depth checked along the way.
String _shape(List<TaskTreeNode> nodes, [int depth = 0]) => nodes
    .map((node) {
      expect(node.depth, depth, reason: 'depth of ${node.task.id}');
      return node.children.isEmpty
          ? '${node.task.id}'
          : '${node.task.id}(${_shape(node.children, depth + 1)})';
    })
    .join(', ');

String _tree(List<Task> matching, [List<Task> others = const []]) => _shape(
  buildTaskTree(
    matching: matching,
    tasksById: {
      for (final task in [...matching, ...others]) task.id: task,
    },
  ),
);

void main() {
  group('useTaskListFiltering.test.ts', () {
    test('1a a task without parents shows', () {
      expect(_showsAtTopLevel(task(1), [1, 2]), isTrue);
    });

    test('1b a task whose parent is in the view does not', () {
      expect(_showsAtTopLevel(task(2, parentIds: [1]), [1, 2]), isFalse);
    });

    test('2 a parent in another project, absent from the view', () {
      final child = task(2, projectId: 200, parentIds: [1]);
      expect(_showsAtTopLevel(child, [2]), isTrue);
    });

    // 3b's undefined related tasks are normalised to 3a's empty object.
    test('3a and 3b no related tasks', () {
      expect(
        _showsAtTopLevel(const Task(id: 1, title: 'Task 1', projectId: 1), [1]),
        isTrue,
      );
    });

    test('3c an empty parent list', () {
      expect(
        _showsAtTopLevel(
          const Task(
            id: 1,
            title: 'Task 1',
            projectId: 1,
            relatedTasks: {TaskRelationKind.parentTask: []},
          ),
          [1],
        ),
        isTrue,
      );
    });

    group('4 three levels all in the view', () {
      test('a the grandparent shows', () {
        expect(_showsAtTopLevel(task(1), [1, 2, 3]), isTrue);
      });

      test('b the parent does not', () {
        expect(_showsAtTopLevel(task(2, parentIds: [1]), [1, 2, 3]), isFalse);
      });

      test('c the child does not, although its parent is hidden too', () {
        expect(_showsAtTopLevel(task(3, parentIds: [2]), [1, 2, 3]), isFalse);
      });
    });

    test('5 two parents, neither in the view', () {
      expect(_showsAtTopLevel(task(3, parentIds: [1, 2]), [3]), isTrue);
    });

    test('6 two parents, both in the view', () {
      expect(_showsAtTopLevel(task(3, parentIds: [1, 2]), [1, 2, 3]), isFalse);
    });

    test('one of two parents in the view is enough to hide', () {
      expect(_showsAtTopLevel(task(3, parentIds: [1, 2]), [2, 3]), isFalse);
    });
  });

  group('buildTaskTree', () {
    test('tasks without relations are rows in the given order', () {
      expect(_tree([task(3), task(1), task(2)]), '3, 1, 2');
    });

    test('nothing in, nothing out', () {
      expect(buildTaskTree(matching: const [], tasksById: const {}), isEmpty);
    });

    test('two levels below a root, children right under their parent', () {
      expect(
        _tree([
          task(4),
          task(3, parentIds: [2]),
          task(2, parentIds: [1], subtaskIds: [3]),
          task(1, subtaskIds: [2]),
        ]),
        '4, 1(2(3))',
      );
    });

    test('children in the order of the subtask list, not the view', () {
      expect(
        _tree([
          task(1, subtaskIds: [4, 2, 3]),
          task(2, parentIds: [1]),
          task(3, parentIds: [1]),
          task(4, parentIds: [1]),
        ]),
        '1(4, 2, 3)',
      );
    });

    test('a child in another project rides along', () {
      final tree = buildTaskTree(
        matching: [
          task(1, subtaskIds: [10]),
        ],
        tasksById: {
          1: task(1, subtaskIds: [10]),
          10: task(10, projectId: 2, parentIds: [1]),
        },
      );

      expect(_shape(tree), '1(10)');
      expect(tree.single.children.single.task.projectId, 2);
    });

    test('a done child stays under its open parent', () {
      final tree = buildTaskTree(
        matching: [
          task(1, subtaskIds: [2]),
        ],
        tasksById: {
          1: task(1, subtaskIds: [2]),
          2: task(2, done: true, parentIds: [1]),
        },
      );

      expect(_shape(tree), '1(2)');
      expect(tree.single.children.single.task.done, isTrue);
    });

    test('an open child of a done parent outside the list is a row', () {
      expect(
        _tree(
          [
            task(3),
            task(2, parentIds: [1]),
          ],
          [
            task(1, done: true, subtaskIds: [2]),
          ],
        ),
        '3, 2',
      );
    });

    test('a child of two shown parents appears under both', () {
      expect(
        _tree([
          task(1, subtaskIds: [3]),
          task(2, subtaskIds: [3]),
          task(3, parentIds: [1, 2]),
        ]),
        '1(3), 2(3)',
      );
    });

    test('a child missing from tasksById is left out', () {
      expect(
        _tree([
          task(1, subtaskIds: [99, 2]),
          task(2, parentIds: [1]),
        ]),
        '1(2)',
      );
    });

    test('a child found only in the view is not looked up there', () {
      final tree = buildTaskTree(
        matching: [
          task(1, subtaskIds: [2]),
          task(2, parentIds: [1]),
        ],
        tasksById: {
          1: task(1, subtaskIds: [2]),
        },
      );

      expect(_shape(tree), '1');
    });

    test('children come from tasksById', () {
      final tree = buildTaskTree(
        matching: [
          task(1, subtaskIds: [2]),
        ],
        tasksById: {
          1: task(1, subtaskIds: [2]),
          2: task(2, title: 'From the database', parentIds: [1]),
        },
      );

      expect(tree.single.children.single.task.title, 'From the database');
    });

    // Every task of the cycle has a parent the server sends, so the web
    // shows none of them.
    test('a relation cycle reached only from its own task shows nothing', () {
      expect(
        _tree(
          [
            task(1, parentIds: [3], subtaskIds: [2]),
          ],
          [
            task(2, parentIds: [1], subtaskIds: [3]),
            task(3, parentIds: [2], subtaskIds: [1]),
          ],
        ),
        '',
      );
    });

    test('a task repeated through a cycle shows again without subtasks', () {
      expect(
        _tree(
          [
            task(0, subtaskIds: [1]),
          ],
          [
            task(1, parentIds: [0, 3], subtaskIds: [2]),
            task(2, parentIds: [1], subtaskIds: [3]),
            task(3, parentIds: [2], subtaskIds: [1]),
          ],
        ),
        '0(1(2(3(1))))',
      );
    });

    test('a task that is its own subtask', () {
      expect(
        _tree([
          task(1, subtaskIds: [1]),
        ]),
        '1(1)',
      );
    });

    test('a task that is its own subtask and parent shows nothing', () {
      expect(
        _tree([
          task(1, parentIds: [1], subtaskIds: [1]),
        ]),
        '',
      );
    });

    test('a cycle entirely inside the list hides all of it, as on the web', () {
      expect(
        _tree([
          task(1, parentIds: [2], subtaskIds: [2]),
          task(2, parentIds: [1], subtaskIds: [1]),
        ]),
        '',
      );
    });

    test('a task below a node twice on different paths is not a cycle', () {
      expect(
        _tree([
          task(1, subtaskIds: [2, 3]),
          task(2, parentIds: [1], subtaskIds: [4]),
          task(3, parentIds: [1], subtaskIds: [4]),
          task(4, parentIds: [2, 3]),
        ]),
        '1(2(4), 3(4))',
      );
    });

    test('five levels below a top-level row at most, as on the web since '
        '2.8.0', () {
      final chain = [
        for (var id = 1; id <= 12; id++)
          task(
            id,
            parentIds: [if (id > 1) id - 1],
            subtaskIds: [if (id < 12) id + 1],
          ),
      ];

      expect(_tree(chain), '1(2(3(4(5(6)))))');
    });

    test('a diamond expands the shared task where it first appears', () {
      expect(
        _tree([
          task(1, subtaskIds: [2, 3]),
          task(2, parentIds: [1], subtaskIds: [4]),
          task(3, parentIds: [1], subtaskIds: [4]),
          task(4, parentIds: [2, 3], subtaskIds: [5]),
          task(5, parentIds: [4]),
        ]),
        '1(2(4(5)), 3(4))',
      );
    });

    test('a subtask of two top-level rows is expanded under each', () {
      expect(
        _tree([
          task(1, subtaskIds: [3]),
          task(2, subtaskIds: [3]),
          task(3, parentIds: [1, 2], subtaskIds: [4]),
          task(4, parentIds: [3]),
        ]),
        '1(3(4)), 2(3(4))',
      );
    });

    test(
      'the first appearance depth first is expanded, not the shallowest',
      () {
        expect(
          _tree([
            task(1, subtaskIds: [2, 3]),
            task(2, parentIds: [1], subtaskIds: [3]),
            task(3, parentIds: [1, 2], subtaskIds: [4]),
            task(4, parentIds: [3]),
          ]),
          '1(2(3(4)), 3)',
        );
      },
    );

    test('an open task below a done subtask of a listed task is no row of its '
        "own, as the web shows the server's answer", () {
      expect(
        _tree(
          [
            task(1, subtaskIds: [2]),
            task(3, parentIds: [2]),
          ],
          [
            task(2, done: true, parentIds: [1], subtaskIds: [3]),
          ],
        ),
        '1(2(3))',
      );
    });

    test('a matching task under a cycle no root reaches stays a row', () {
      expect(
        _tree(
          [
            task(1, parentIds: [2], subtaskIds: [2, 3]),
            task(2, parentIds: [1], subtaskIds: [1]),
            task(4, parentIds: [3]),
          ],
          [
            task(3, done: true, parentIds: [1], subtaskIds: [4]),
          ],
        ),
        '4',
      );
    });

    test('a child of such a cycle shows nowhere, as on the web', () {
      expect(
        _tree([
          task(1, parentIds: [2], subtaskIds: [2, 5]),
          task(2, parentIds: [1], subtaskIds: [1]),
          task(5, parentIds: [1]),
        ]),
        '',
      );
    });
  });

  group('SingleTaskInProject.test.ts', () {
    List<int> flattened(List<TaskTreeNode> nodes) => [
      for (final node in nodes) ...[node.task.id, ...flattened(node.children)],
    ];

    List<int> rowsOf(Map<int, List<int>> subtasksById) {
      final tasks = {
        for (final MapEntry(key: id, value: subtaskIds) in subtasksById.entries)
          id: task(id, subtaskIds: subtaskIds),
      };
      return flattened(buildTaskTree(matching: [tasks[1]!], tasksById: tasks));
    }

    test('a 4x4 diamond renders at most one row per edge and the root', () {
      final levels = [
        [1],
        for (var level = 0; level < 4; level++)
          [for (var i = 0; i < 4; i++) 2 + level * 4 + i],
      ];
      final subtasksById = {
        for (var level = 0; level < levels.length; level++)
          for (final id in levels[level])
            id: level + 1 < levels.length ? levels[level + 1] : <int>[],
      };
      final edges = subtasksById.values.fold(0, (sum, ids) => sum + ids.length);

      final rows = rowsOf(subtasksById);

      expect(subtasksById, hasLength(17));
      expect(edges, 52);
      expect(rows, hasLength(edges + 1));
      expect(rows.toSet(), subtasksById.keys.toSet());
    });

    test('a plain tree renders every task once', () {
      expect(
        rowsOf({
          1: [2, 3],
          2: [4, 5],
          3: [6],
          4: [],
          5: [],
          6: [],
        }),
        [1, 2, 4, 5, 3, 6],
      );
    });

    test('a chain of 10 stops five levels below the root', () {
      expect(
        rowsOf({
          for (var id = 1; id <= 10; id++) id: [if (id < 10) id + 1],
        }),
        [1, 2, 3, 4, 5, 6],
      );
    });
  });
}
