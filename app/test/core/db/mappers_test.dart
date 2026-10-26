import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/epoch_millis.dart';
import 'package:vikunja_mobile/core/db/mappers/label_mappers.dart';
import 'package:vikunja_mobile/core/db/mappers/project_mappers.dart';
import 'package:vikunja_mobile/core/db/mappers/task_mappers.dart';
import 'package:vikunja_mobile/core/db/mappers/user_mappers.dart';

void main() {
  const alice = User(id: 7, username: 'alice', name: 'Alice Example');
  const bob = User(id: 8, username: 'bob');
  final created = DateTime.utc(2026, 10, 1, 8, 30, 15, 250);
  final updated = DateTime.utc(2026, 10, 9, 17, 45);

  test('epoch millis keep the instant in UTC', () {
    const converter = EpochMillis();
    final local = DateTime(2026, 10, 10, 12, 34, 56, 789);

    expect(converter.toSql(local), local.toUtc().millisecondsSinceEpoch);
    final back = converter.fromSql(converter.toSql(local));
    expect(back.isUtc, isTrue);
    expect(back, local.toUtc());
  });

  test('user round trip drops the email', () {
    const me = User(id: 1, username: 'me', name: 'Me', email: 'me@x.org');

    final back = userFromRow(userRow(me));

    expect(back, const User(id: 1, username: 'me', name: 'Me'));
  });

  test('label round trip', () {
    final label = Label(
      id: 3,
      title: 'urgent',
      description: 'Drop everything',
      hexColor: 'e8323c',
      createdBy: alice,
      created: created,
      updated: updated,
    );

    final row = labelRow(label);
    final back = labelFromRow(row, createdBy: alice);

    expect(row.createdById, alice.id);
    expect(back, label);
    expect(back.description, label.description);
    expect(back.createdBy, alice);
    expect(back.created, created);
    expect(back.updated, updated);
    expect(
      labelFromRow(labelRow(const Label(id: 4, title: 'bare'))),
      const Label(id: 4, title: 'bare'),
    );
  });

  group('project', () {
    const filter = ViewFilter(
      filter: 'done = false',
      search: 'needle',
      sortBy: ['due_date', 'id'],
      orderBy: ['asc', 'desc'],
      includeNulls: true,
    );
    final views = [
      const ProjectView(
        id: 11,
        projectId: 1,
        title: 'List',
        kind: ProjectViewKind.list,
        filter: filter,
      ),
      const ProjectView(
        id: 12,
        projectId: 1,
        title: 'Board',
        kind: ProjectViewKind.kanban,
        position: 2,
        bucketConfigurationMode: BucketConfigurationMode.manual,
        defaultBucketId: 5,
        doneBucketId: 6,
      ),
    ];
    final project = Project(
      id: 1,
      title: 'Work',
      description: '<p>Things</p>',
      identifier: 'WRK',
      hexColor: '1973ff',
      isArchived: true,
      isFavorite: true,
      position: 65536,
      owner: alice,
      views: views,
      created: created,
      updated: updated,
      maxPermission: Permission.write,
    );

    test('an unknown permission stays unknown', () {
      final unknown = project.copyWith(maxPermission: null);

      expect(projectRow(unknown).maxPermission, isNull);
      expect(
        projectFromRow(projectRow(unknown), views: const []).maxPermission,
        isNull,
      );
      expect(
        projectFromRow(
          projectRow(unknown).copyWith(maxPermission: const Value(7)),
          views: const [],
        ).maxPermission,
        isNull,
        reason: 'a value this build does not know',
      );
    });

    test('round trip with views, filter and owner', () {
      final row = projectRow(project);
      final viewRows = views.map(projectViewRow).toList();
      final back = projectFromRow(row, views: viewRows, owner: alice);

      expect(row.ownerId, alice.id);
      expect(back, project);
      expect(back.description, project.description);
      expect(back.isArchived, isTrue);
      expect(back.owner, alice);
      expect(back.created, created);
      expect(back.updated, updated);
      expect(back.maxPermission, Permission.write);
      expect(row.maxPermission, 1);
      expect(back.views, views);
      final list = back.views.first;
      expect(list.title, 'List');
      expect(list.kind, ProjectViewKind.list);
      expect(list.filter?.filter, filter.filter);
      expect(list.filter?.search, filter.search);
      expect(list.filter?.sortBy, filter.sortBy);
      expect(list.filter?.orderBy, filter.orderBy);
      expect(list.filter?.includeNulls, isTrue);
      final board = back.views.last;
      expect(board.filter, isNull);
      expect(board.position, 2);
      expect(board.bucketConfigurationMode, BucketConfigurationMode.manual);
      expect(board.defaultBucketId, 5);
      expect(board.doneBucketId, 6);
    });

    test('a view of an unknown kind is dropped, like the codec does', () {
      final row = projectViewRow(views.first);
      final unknown = ProjectViewRow(
        id: row.id,
        projectId: row.projectId,
        title: row.title,
        kind: 'calendar',
        position: 0,
        bucketConfigurationMode: 'none',
        defaultBucketId: 0,
        doneBucketId: 0,
      );

      expect(projectViewFromRow(unknown), isNull);
      expect(
        projectFromRow(projectRow(project), views: [unknown]).views,
        isEmpty,
      );
    });

    test('view filter JSON uses the wire names', () {
      expect(encodeViewFilter(null), isNull);
      expect(decodeViewFilter(null), isNull);
      expect(
        encodeViewFilter(filter),
        jsonEncode({
          'filter': 'done = false',
          's': 'needle',
          'sort_by': ['due_date', 'id'],
          'order_by': ['asc', 'desc'],
          'filter_include_nulls': true,
        }),
      );
      expect(decodeViewFilter('{}')?.filter, '');
      expect(decodeViewFilter('[]'), isNull);
    });
  });

  group('task', () {
    final due = DateTime.utc(2026, 10, 12, 9);
    final reminders = [
      TaskReminder(reminder: due.subtract(const Duration(minutes: 10))),
      const TaskReminder(
        relativePeriod: Duration(hours: -1),
        relativeTo: ReminderRelativeTo.dueDate,
      ),
    ];
    const label = Label(id: 3, title: 'urgent', hexColor: 'e8323c');
    const parent = Task(id: 40, title: 'Parent', projectId: 1);
    final task = Task(
      id: 42,
      title: 'Write the report',
      projectId: 1,
      description: '<p>Soon</p>',
      done: true,
      doneAt: updated,
      dueDate: due,
      startDate: created,
      endDate: due,
      priority: TaskPriority.urgent,
      percentDone: 0.5,
      hexColor: 'abcdef',
      identifier: 'WRK-12',
      index: 12,
      isFavorite: true,
      position: 1234.5,
      labels: const [label],
      assignees: const [alice, bob],
      reminders: reminders,
      repeatAfter: const Duration(days: 7),
      repeatMode: RepeatMode.fromCurrentDate,
      relatedTasks: const {
        TaskRelationKind.parentTask: [parent],
      },
      bucketId: 9,
      createdBy: alice,
      created: created,
      updated: updated,
      commentCount: 3,
      isUnread: true,
    );

    test('round trip through the rows', () {
      final row = taskRow(task, syncRunId: 'run-1');
      final back = taskFromRow(
        row,
        createdBy: alice,
        labels: const [label],
        assignees: const [alice, bob],
        reminders: reminders,
        relatedTasks: {
          TaskRelationKind.parentTask: [parent],
        },
      );

      expect(row.syncRunId, 'run-1');
      expect(row.taskIndex, 12);
      expect(row.createdById, alice.id);
      expect(row.repeatAfter, 7 * 24 * 3600);
      expect(back, task);
      expect(back.description, task.description);
      expect(back.doneAt, updated);
      expect(back.startDate, created);
      expect(back.endDate, due);
      expect(back.priority, TaskPriority.urgent);
      expect(back.percentDone, 0.5);
      expect(back.displayIdentifier, 'WRK-12');
      expect(back.labels, const [label]);
      expect(back.assignees, const [alice, bob]);
      expect(back.reminders, reminders);
      expect(back.repeatAfter, const Duration(days: 7));
      expect(back.repeatMode, RepeatMode.fromCurrentDate);
      expect(back.parentTasks, [parent]);
      expect(back.bucketId, 9);
      expect(back.createdBy, alice);
      expect(back.created, created);
      expect(back.updated, updated);
      expect(row.commentCount, 3);
      expect(row.isUnread, isTrue);
      expect(back.commentCount, 3);
      expect(back.isUnread, isTrue);
    });

    test('child rows carry the task id, ordinals and wire names', () {
      expect(taskLabelRows(task), [const TaskLabelRow(taskId: 42, labelId: 3)]);
      expect(taskAssigneeRows(task), [
        const TaskAssigneeRow(taskId: 42, userId: 7),
        const TaskAssigneeRow(taskId: 42, userId: 8),
      ]);
      final reminderRows = taskReminderRows(task);
      expect(reminderRows.map((r) => r.ordinal), [0, 1]);
      expect(reminderRows.first.reminder, reminders.first.reminder);
      expect(reminderRows.first.relativeTo, isNull);
      expect(reminderRows.last.relativePeriod, -3600);
      expect(reminderRows.last.relativeTo, 'due_date');
      expect(reminderRows.map(reminderFromRow), reminders);
      expect(taskRelationRows(task), [
        const TaskRelationRow(taskId: 42, otherTaskId: 40, kind: 'parenttask'),
      ]);
    });

    test('a bare task maps to its defaults', () {
      const bare = Task(id: 1, title: 'Bare', projectId: 2);

      final back = taskFromRow(taskRow(bare, syncRunId: 'r'));

      expect(back, bare);
      expect(back.dueDate, isNull);
      expect(back.priority, TaskPriority.unset);
      expect(back.labels, isEmpty);
      expect(back.relatedTasks, isEmpty);
      expect(back.repeats, isFalse);
      expect(back.createdBy, isNull);
      expect(back.commentCount, 0);
      expect(back.isUnread, isFalse);
    });
  });
}
