import 'dart:convert';

import 'package:background_downloader/background_downloader.dart'
    show TaskStatusUpdate;
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/home_widget_store.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/task_attachment.dart';
import 'package:vikunja_app/domain/entities/user.dart';
import 'package:vikunja_app/domain/repositories/project_repository.dart';
import 'package:vikunja_app/domain/repositories/task_repository.dart';
import 'package:vikunja_app/presentation/manager/widget_controller.dart';

class FakeHomeWidgetStore implements HomeWidgetStore {
  final Map<String, Object?> data = {};
  int rerenderCount = 0;

  @override
  Future<T?> read<T>(String key) async => data[key] as T?;

  @override
  Future<void> write(String key, Object? value) async => data[key] = value;

  @override
  Future<void> rerenderWidget() async => rerenderCount++;
}

class MockTaskRepository implements TaskRepository {
  Future<Response<Task>> Function(Task task)? updateStub;
  Future<Response<Task>> Function(int projectId, Task task)? addStub;
  Future<Response<Task>> Function(int id)? getTaskStub;
  Future<Response<List<Task>>> Function(
    String filterString,
    Map<String, List<String>>? queryParameters,
  )?
  getByFilterStringStub;
  Future<Response<List<Task>>> Function(
    int projectId,
    Map<String, List<String>>? queryParameters,
  )?
  getAllByProjectStub;
  Future Function(int taskId)? deleteStub;

  @override
  Future<Response<Task>> add(int projectId, Task task) {
    return addStub!(projectId, task);
  }

  @override
  Future delete(int taskId) {
    return deleteStub!(taskId);
  }

  @override
  Future<Response<Task>> update(Task task) {
    return updateStub!(task);
  }

  @override
  Future<Response<Task>> getTask(int id) {
    return getTaskStub!(id);
  }

  @override
  Future<Response<List<Task>>> getAllByProject(
    int projectId, [
    Map<String, List<String>>? queryParameters,
  ]) {
    return getAllByProjectStub!(projectId, queryParameters);
  }

  @override
  Future<Response<List<Task>>> getAllByProjectView(
    int projectId,
    int view, [
    Map<String, List<String>>? queryParameters,
  ]) {
    throw UnimplementedError();
  }

  @override
  Future<Response<List<Task>>> getByFilterString(
    String filterString, [
    Map<String, List<String>>? queryParameters,
  ]) {
    return getByFilterStringStub!(filterString, queryParameters);
  }

  @override
  Future<TaskStatusUpdate> downloadAttachment(
    int taskId,
    TaskAttachment attachment,
  ) {
    throw UnimplementedError();
  }
}

class MockProjectRepository implements ProjectRepository {
  Future<Response<List<Project>>> Function(int page)? getAllStub;

  @override
  Future<Response<List<Project>>> getAll({int page = 1}) {
    return getAllStub!(page);
  }

  @override
  Future<Response<Project>> create(Project p) => throw UnimplementedError();

  @override
  Future<Response<Project>> update(Project p) => throw UnimplementedError();
}

User _user() => User(username: 'tester');

Task _task(int id, String title, {bool done = false, DateTime? due}) => Task(
  id: id,
  title: title,
  done: done,
  dueDate: due,
  createdBy: _user(),
  projectId: 1,
);

List<Map<String, Object?>> _storedTasks(FakeHomeWidgetStore store, String id) {
  return (jsonDecode(store.data['WidgetTasks_$id']! as String) as List)
      .cast<Map<String, Object?>>();
}

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  group('updateWidgetInstance', () {
    test('renders the undone tasks of a configured saved filter', () async {
      final store = FakeHomeWidgetStore()
        ..data['widget_view_7'] = 'project'
        ..data['widget_project_id_7'] = '-3'
        ..data['widget_project_name_7'] = 'Widget Filter Slice4';
      final requestedProjectIds = <int>[];
      final taskService = MockTaskRepository()
        ..getAllByProjectStub = (projectId, _) async {
          requestedProjectIds.add(projectId);
          return SuccessResponse(
            [
              _task(2, 'Emulator Task 2', due: yesterday),
              _task(1, 'Emulator Task 1', done: true),
            ],
            200,
            {},
          );
        };

      await updateWidgetInstance('7', store: store, taskService: taskService);

      expect(requestedProjectIds, [-3]);
      expect(store.data['widget_title_7'], 'Widget Filter Slice4');
      final stored = _storedTasks(store, '7');
      expect(stored, hasLength(1));
      expect(stored.single['id'], '2');
      expect(stored.single['title'], 'Emulator Task 2');
      expect(
        stored.single['dueDate'],
        yesterday.toUtc().millisecondsSinceEpoch,
      );
      expect(stored.single['today'], isFalse);
    });

    test('renders the undone tasks of a configured project', () async {
      final store = FakeHomeWidgetStore()
        ..data['widget_view_3'] = 'project'
        ..data['widget_project_id_3'] = '5'
        ..data['widget_project_name_3'] = 'Work';
      final taskService = MockTaskRepository()
        ..getAllByProjectStub = (projectId, _) async => SuccessResponse(
          [_task(11, 'Open', due: today), _task(12, 'Closed', done: true)],
          200,
          {},
        );

      await updateWidgetInstance('3', store: store, taskService: taskService);

      expect(store.data['widget_title_3'], 'Work');
      final stored = _storedTasks(store, '3');
      expect(stored, hasLength(1));
      expect(stored.single['title'], 'Open');
      expect(stored.single['today'], isTrue);
    });

    test('defaults to the today view when none is stored', () async {
      final store = FakeHomeWidgetStore();
      final requestedFilters = <String>[];
      final taskService = MockTaskRepository()
        ..getByFilterStringStub = (filterString, _) async {
          requestedFilters.add(filterString);
          return SuccessResponse<List<Task>>([], 200, {});
        };

      await updateWidgetInstance('9', store: store, taskService: taskService);

      expect(requestedFilters, ['done = false && due_date < now/d+1d']);
      expect(store.data['widget_title_9'], 'Today');
      expect(_storedTasks(store, '9'), isEmpty);
    });

    test('inbox view requests all undone tasks', () async {
      final store = FakeHomeWidgetStore()..data['widget_view_1'] = 'inbox';
      final requestedFilters = <String>[];
      final taskService = MockTaskRepository()
        ..getByFilterStringStub = (filterString, _) async {
          requestedFilters.add(filterString);
          return SuccessResponse<List<Task>>([], 200, {});
        };

      await updateWidgetInstance('1', store: store, taskService: taskService);

      expect(requestedFilters, ['done = false']);
      expect(store.data['widget_title_1'], 'Inbox');
    });

    test('upcoming view requests the next seven days', () async {
      final store = FakeHomeWidgetStore()..data['widget_view_2'] = 'upcoming';
      final requests = <(String, Map<String, List<String>>?)>[];
      final taskService = MockTaskRepository()
        ..getByFilterStringStub = (filterString, queryParameters) async {
          requests.add((filterString, queryParameters));
          return SuccessResponse<List<Task>>([], 200, {});
        };

      await updateWidgetInstance('2', store: store, taskService: taskService);

      expect(
        requests.single.$1,
        'done = false && due_date >= now/d && due_date < now/d+7d',
      );
      expect(requests.single.$2, {
        'filter_include_nulls': ['false'],
      });
      expect(store.data['widget_title_2'], 'Upcoming');
    });

    test('keeps the last good task list when the fetch fails', () async {
      final store = FakeHomeWidgetStore()
        ..data['widget_view_4'] = 'today'
        ..data['WidgetTasks_4'] = '[{"id":"1","title":"cached"}]';
      final taskService = MockTaskRepository()
        ..getByFilterStringStub = (filterString, _) async =>
            ErrorResponse<List<Task>>(500, {}, {'message': 'boom'});

      await updateWidgetInstance('4', store: store, taskService: taskService);

      expect(store.data['widget_title_4'], 'Today');
      expect(store.data['WidgetTasks_4'], '[{"id":"1","title":"cached"}]');
    });
  });

  group('syncWidgetProjectOptions', () {
    test('syncs every page of projects and saved filters', () async {
      final store = FakeHomeWidgetStore();
      final projectService = MockProjectRepository()
        ..getAllStub = (page) async {
          if (page == 1) {
            return SuccessResponse(
              [
                Project(id: 1, title: 'Inbox'),
                Project(id: -2, title: 'My Open Tasks'),
              ],
              200,
              {'x-pagination-total-pages': '2'},
            );
          }
          return SuccessResponse(
            [Project(id: -3, title: 'Widget Filter Slice4')],
            200,
            {'x-pagination-total-pages': '2'},
          );
        };

      await syncWidgetProjectOptions(
        projectService: projectService,
        store: store,
      );

      expect(store.data['WidgetProjects'], isNotNull);
      expect(jsonDecode(store.data['WidgetProjects']! as String), [
        {'id': 1, 'title': 'Inbox'},
        {'id': -2, 'title': 'My Open Tasks'},
        {'id': -3, 'title': 'Widget Filter Slice4'},
      ]);
    });

    test('syncs a single page when no pagination header is present', () async {
      final store = FakeHomeWidgetStore();
      final requestedPages = <int>[];
      final projectService = MockProjectRepository()
        ..getAllStub = (page) async {
          requestedPages.add(page);
          return SuccessResponse([Project(id: 1, title: 'Inbox')], 200, {});
        };

      await syncWidgetProjectOptions(
        projectService: projectService,
        store: store,
      );

      expect(requestedPages, [1]);
      expect(jsonDecode(store.data['WidgetProjects']! as String), [
        {'id': 1, 'title': 'Inbox'},
      ]);
    });

    test('keeps the last good project list when a page fetch fails', () async {
      final store = FakeHomeWidgetStore()
        ..data['WidgetProjects'] = '[{"id":1,"title":"old"}]';
      final projectService = MockProjectRepository()
        ..getAllStub = (page) async =>
            ErrorResponse<List<Project>>(500, {}, {'message': 'boom'});

      await syncWidgetProjectOptions(
        projectService: projectService,
        store: store,
      );

      expect(store.data['WidgetProjects'], '[{"id":1,"title":"old"}]');
    });
  });
}
