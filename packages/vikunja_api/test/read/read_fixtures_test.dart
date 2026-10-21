import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';

// Captured by tool/capture_read_fixtures.dart from a 2.7.0 server: an Inbox,
// a project FX with a child, two labels and three tasks (a parent with
// labels, reminders and an assignee; its favourite subtask; a done task).
typedef _Reads = ({
  Page<Project> projects,
  Project project,
  Page<Label> labels,
  Page<Task> tasks,
  Task task,
});

Future<_Reads> _read(ApiVersion version) async {
  final base = '$testServerRoot/api/${version.pathSegment}';
  final prefix = 'read/${version.pathSegment}';
  final dio = fakeDio({
    '$base/projects?page=1&per_page=2': capturedFixture(
      '${prefix}_projects_page_2.7.0',
    ),
    '$base/projects/19': capturedFixture('${prefix}_project_with_views_2.7.0'),
    '$base/labels?page=1': capturedFixture('${prefix}_labels_page_2.7.0'),
    '$base/projects/19/tasks?sort_by=id&order_by=asc&page=1': capturedFixture(
      '${prefix}_tasks_page_2.7.0',
    ),
    '$base/tasks/13': capturedFixture('${prefix}_task_2.7.0'),
  });
  final client = createReadClient(
    dio: dio,
    connection: testConnection(hasV2: version == ApiVersion.v2),
  );
  return (
    projects: await client.projects.list(perPage: 2),
    project: await client.projects.read(19),
    labels: await client.labels.list(),
    tasks: await client.tasks.listInProject(
      19,
      const TaskQuery(sort: [TaskSort(TaskSortField.id)]),
    ),
    task: await client.tasks.read(13),
  );
}

void main() {
  late Map<ApiVersion, _Reads> reads;

  setUpAll(() async {
    reads = {for (final v in ApiVersion.values) v: await _read(v)};
  });

  for (final version in ApiVersion.values) {
    group(version.pathSegment, () {
      test('projects page: real projects plus the pseudo projects', () {
        final page = reads[version]!.projects;

        expect(page.items.map((p) => p.id), [18, 19, -1, -14]);
        expect(page.page, 1);
        expect(page.perPage, 2);
        expect(page.totalPages, 2);
        expect(page.hasMore, isTrue);
        expect(page.total, version == ApiVersion.v2 ? 3 : isNull);

        final inbox = page.items[0];
        expect(inbox.title, 'Inbox');
        expect(inbox.isTopLevel, isTrue);
        expect(inbox.views, hasLength(4));

        final fixture = page.items[1];
        expect(fixture.title, 'Fixture project');
        expect(fixture.identifier, 'FX');
        expect(fixture.hexColor, '1973ff');
        expect(fixture.owner?.username, 'fixtureuser');
        expect(fixture.isFavorite, isFalse);
        expect(fixture.views.map((v) => v.kind), [
          ProjectViewKind.list,
          ProjectViewKind.gantt,
          ProjectViewKind.table,
          ProjectViewKind.kanban,
        ]);

        final favorites = page.items[2];
        expect(favorites.isFavoritesPseudo, isTrue);
        expect(favorites.isFavorite, isTrue);
        expect(favorites.title, 'Favorites');
        expect(favorites.views.map((v) => v.id), [-1, -2, -3]);
        expect(favorites.views.first.filter?.filter, 'done = false');

        final savedFilter = page.items[3];
        expect(savedFilter.isPseudo, isTrue);
        expect(savedFilter.savedFilterId, 13);
        expect(savedFilter.title, 'My Open Tasks');
      });

      test('project read: the four default views', () {
        final project = reads[version]!.project;

        expect(project.id, 19);
        expect(project.description, '<p>Captured for the read fixtures</p>');
        expect(project.position, 1245184);
        expect(project.created, DateTime.utc(2026, 10, 10, 8, 12, 10));
        expect(project.views.map((v) => (v.id, v.title, v.position)), [
          (125, 'List', 100.0),
          (126, 'Gantt', 200.0),
          (127, 'Table', 300.0),
          (128, 'Kanban', 400.0),
        ]);
        expect(project.views.map((v) => v.projectId), everyElement(19));

        final list = project.views[0];
        expect(list.filter?.filter, 'done = false');
        expect(list.filter?.sortBy, isEmpty);
        expect(list.filter?.includeNulls, isFalse);
        expect(list.bucketConfigurationMode, BucketConfigurationMode.none);
        expect(project.views[1].filter, isNull);

        final kanban = project.views[3];
        expect(kanban.bucketConfigurationMode, BucketConfigurationMode.manual);
        expect(kanban.defaultBucketId, 94);
        expect(kanban.doneBucketId, 96);
      });

      test('labels page', () {
        final page = reads[version]!.labels;

        expect(page.items.map((l) => (l.id, l.title, l.hexColor)), [
          (4, 'urgent', 'e8323c'),
          (5, 'home', '4caf50'),
        ]);
        expect(page.items[1].description, 'Things at home');
        expect(page.items.map((l) => l.createdBy?.username), [
          'fixtureuser',
          'fixtureuser',
        ]);
        expect(page.totalPages, 1);
        expect(page.hasMore, isFalse);
        expect(page.total, version == ApiVersion.v2 ? 2 : isNull);
      });

      test('tasks page: labels, assignees, reminders, relations', () {
        final page = reads[version]!.tasks;
        expect(page.items.map((t) => t.id), [13, 14, 15]);
        expect(page.perPage, 50);
        expect(page.totalPages, 1);

        final parent = page.items[0];
        expect(parent.title, 'Parent task');
        expect(parent.projectId, 19);
        expect(parent.identifier, 'FX-1');
        expect(parent.displayIdentifier, 'FX-1');
        expect(
          parent.description,
          '<p>Hello <strong>world</strong> &amp; friends</p>',
        );
        expect(parent.done, isFalse);
        expect(parent.doneAt, isNull);
        expect(parent.dueDate, DateTime.utc(2026, 10, 11, 8, 12, 10));
        expect(parent.startDate, DateTime.utc(2026, 10, 10, 8, 12, 10));
        expect(parent.endDate, DateTime.utc(2026, 10, 12, 8, 12, 10));
        expect(parent.priority, TaskPriority.high);
        expect(parent.percentDone, 0.25);
        expect(parent.hexColor, 'ff00aa');
        expect(parent.repeatAfter, const Duration(days: 7));
        expect(parent.repeatMode, RepeatMode.afterAmount);
        expect(parent.repeats, isTrue);
        expect(parent.labels.map((l) => (l.id, l.title, l.hexColor)), [
          (4, 'urgent', 'e8323c'),
          (5, 'home', '4caf50'),
        ]);
        expect(parent.assignees.map((u) => (u.id, u.username)), [
          (13, 'fixtureuser'),
        ]);
        expect(parent.createdBy?.username, 'fixtureuser');
        // The server sorts reminders by time and fills in the relative one.
        expect(parent.reminders, [
          TaskReminder(reminder: DateTime.utc(2026, 10, 10, 10, 12, 10)),
          TaskReminder(
            reminder: DateTime.utc(2026, 10, 11, 7, 12, 10),
            relativePeriod: const Duration(hours: -1),
            relativeTo: ReminderRelativeTo.dueDate,
          ),
        ]);
        expect(parent.relatedTasks.keys, [TaskRelationKind.subtask]);
        final nested = parent.subtasks.single;
        expect(nested.id, 14);
        expect(nested.title, 'Subtask');
        // Nested tasks come without identifier, relations and creator.
        expect(nested.identifier, '');
        expect(nested.displayIdentifier, '#2');
        expect(nested.relatedTasks, isEmpty);
        expect(nested.createdBy, isNull);
        expect(nested.isFavorite, isTrue);

        final subtask = page.items[1];
        expect(subtask.identifier, 'FX-2');
        expect(subtask.isFavorite, isTrue);
        expect(subtask.parentTasks.map((t) => t.id), [13]);
        expect(subtask.labels, isEmpty);
        expect(subtask.reminders, isEmpty);
        expect(subtask.dueDate, isNull);

        final done = page.items[2];
        expect(done.identifier, 'FX-3');
        expect(done.done, isTrue);
        // Created as done: the server leaves done_at at the zero date.
        expect(done.doneAt, isNull);
        expect(done.repeatMode, RepeatMode.monthly);
        expect(done.repeats, isTrue);
        expect(done.relatedTasks, isEmpty);
      });

      test('single task read equals the list entry', () {
        final (:tasks, :task, projects: _, project: _, labels: _) =
            reads[version]!;
        final listed = tasks.items[0];

        expect(task, listed);
        expect(task.labels, listed.labels);
        expect(task.assignees, listed.assignees);
        expect(task.reminders, listed.reminders);
        expect(task.subtasks, listed.subtasks);
        expect(task.commentCount, 0);
        expect(task.isUnread, isFalse);
      });
    });
  }

  test('v1 and v2 give the same domain objects except Page.total', () {
    final v1 = reads[ApiVersion.v1]!;
    final v2 = reads[ApiVersion.v2]!;

    expect(v1.projects.items, v2.projects.items);
    expect(v1.projects.totalPages, v2.projects.totalPages);
    expect(v1.projects.perPage, v2.projects.perPage);
    expect(v1.project, v2.project);
    expect(v1.project.views, v2.project.views);
    expect(
      v1.project.views.map((v) => v.filter?.filter),
      v2.project.views.map((v) => v.filter?.filter),
    );
    expect(v1.labels.items, v2.labels.items);
    expect(v1.tasks.items, v2.tasks.items);
    for (final (a, b) in [
      for (var i = 0; i < 3; i++) (v1.tasks.items[i], v2.tasks.items[i]),
    ]) {
      expect(a.labels, b.labels);
      expect(a.assignees, b.assignees);
      expect(a.reminders, b.reminders);
      expect(a.relatedTasks.keys, b.relatedTasks.keys);
      expect(a.subtasks, b.subtasks);
      expect(a.parentTasks, b.parentTasks);
    }
    expect(v1.task, v2.task);
    expect(v1.projects.total, isNull);
    expect(v2.projects.total, 3);
  });
}
