import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/repositories/task_repository.dart';
import 'package:vikunja_app/presentation/manager/widget_controller.dart';

class FakeTaskRepository implements TaskRepository {
  final requests = <Map<String, List<String>>>[];
  final projectIds = <int>[];
  final filters = <String>[];
  late Future<Response<List<Task>>> Function(int page) fetchPage;

  @override
  Future<Response<List<Task>>> getAllByProject(
    int projectId, [
    Map<String, List<String>>? queryParameters,
  ]) {
    projectIds.add(projectId);
    return _fetch(queryParameters!);
  }

  @override
  Future<Response<List<Task>>> getByFilterString(
    String filter, [
    Map<String, List<String>>? queryParameters,
  ]) {
    filters.add(filter);
    return _fetch(queryParameters!);
  }

  Future<Response<List<Task>>> _fetch(Map<String, List<String>> parameters) {
    requests.add(parameters);
    return fetchPage(int.parse(parameters['page']!.single));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Task task(int id, {bool done = false}) =>
    Task(id: id, title: 'Task $id', done: done, projectId: 1, createdBy: null);

void main() {
  test('project widget requests open tasks and includes every page', () async {
    final repository = FakeTaskRepository()
      ..fetchPage = (page) async => SuccessResponse(
        [task(page), task(page + 100, done: true)],
        200,
        {'X-Pagination-Total-Pages': '3'},
      );

    final result = await loadWidgetTasks(repository, projectId: 1);

    expect(result.toSuccess().body.map((task) => task.id), [1, 2, 3]);
    expect(repository.projectIds, [1, 1, 1]);
    expect(repository.filters, isEmpty);
    expect(repository.requests, [
      {
        'filter': ['done = false'],
        'page': ['1'],
      },
      {
        'filter': ['done = false'],
        'page': ['2'],
      },
      {
        'filter': ['done = false'],
        'page': ['3'],
      },
    ]);
  });

  test('an empty first page does not hide tasks on a later page', () async {
    final repository = FakeTaskRepository()
      ..fetchPage = (page) async => SuccessResponse(
        page == 1 ? <Task>[] : [task(2)],
        200,
        {'x-pagination-total-pages': '2'},
      );

    final result = await loadWidgetTasks(repository, projectId: 1);

    expect(result.toSuccess().body.single.id, 2);
    expect(repository.requests.length, 2);
  });

  test('filtered widget views preserve their filters on every page', () async {
    const filter = 'done = false && due_date >= now/d && due_date < now/d+7d';
    final parameters = {
      'filter_include_nulls': ['false'],
    };
    final repository = FakeTaskRepository()
      ..fetchPage = (page) async =>
          SuccessResponse([task(page)], 200, {'x-pagination-total-pages': '2'});

    final result = await loadWidgetTasks(
      repository,
      filter: filter,
      queryParameters: parameters,
    );

    expect(result.toSuccess().body.length, 2);
    expect(repository.filters, [filter, filter]);
    expect(repository.projectIds, isEmpty);
    for (final request in repository.requests) {
      expect(request['filter'], [filter]);
      expect(request['filter_include_nulls'], ['false']);
    }
    expect(parameters.containsKey('page'), isFalse);
  });

  test(
    'later-page failure returns an error rather than partial tasks',
    () async {
      final failure = ErrorResponse<List<Task>>(500, {}, {'message': 'failed'});
      final repository = FakeTaskRepository()
        ..fetchPage = (page) async => page == 1
            ? SuccessResponse([task(1)], 200, {'x-pagination-total-pages': '3'})
            : failure;

      final result = await loadWidgetTasks(repository, projectId: 1);

      expect(result, same(failure));
      expect(repository.requests.length, 2);
    },
  );

  test('without a pagination header only one request is made', () async {
    final repository = FakeTaskRepository()
      ..fetchPage = (page) async => SuccessResponse([task(1)], 200, {});

    final result = await loadWidgetTasks(repository);

    expect(result.toSuccess().body.single.id, 1);
    expect(repository.requests.length, 1);
  });
}
