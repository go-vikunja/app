import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/task_relation.dart';
import 'package:vikunja_app/domain/entities/user.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/blocking_arrows.dart';

Task _task(int id, {Map<RelationKind, List<Task>> related = const {}}) {
  return Task(
    id: id,
    title: 'T$id',
    createdBy: User(username: 'u'),
    projectId: 1,
    relatedTasks: related,
  );
}

void main() {
  test('blocking relation draws A -> B', () {
    final blocked = _task(2);
    final blocker = _task(
      1,
      related: {
        RelationKind.blocking: [blocked],
      },
    );

    expect(blockingLinksFromTasks([blocker, blocked]), {
      const BlockingLink(1, 2),
    });
  });

  test('blocked-by relation inverts to blocker -> blocked', () {
    final blocker = _task(1);
    final blocked = _task(
      2,
      related: {
        RelationKind.blocked: [blocker],
      },
    );

    expect(blockingLinksFromTasks([blocker, blocked]), {
      const BlockingLink(1, 2),
    });
  });

  test('ignores related tasks not on the board', () {
    final missing = _task(99);
    final blocker = _task(
      1,
      related: {
        RelationKind.blocking: [missing],
      },
    );

    expect(blockingLinksFromTasks([blocker]), isEmpty);
  });
}
