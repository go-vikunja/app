import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/user.dart';
import 'package:vikunja_app/domain/repositories/task_repository.dart';
import 'package:vikunja_app/presentation/manager/notifications.dart';

class FakeTaskRepository implements TaskRepository {
  final requests = <Map<String, List<String>>>[];
  final filters = <String>[];
  late Response<List<Task>> Function(int page) fetchPage;

  @override
  Future<Response<List<Task>>> getByFilterString(
    String filterString, [
    Map<String, List<String>>? queryParameters,
  ]) async {
    filters.add(filterString);
    requests.add(queryParameters!);
    return fetchPage(int.parse(queryParameters['page']!.single));
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _user = User(username: 'testuser');

List<Task> _tasks(int from, int count) => List.generate(
  count,
  (i) => Task(
    id: from + i,
    title: 'Task ${from + i}',
    createdBy: _user,
    projectId: 1,
  ),
);

void main() {
  test('fetches every page reported by x-pagination-total-pages', () async {
    final repo = FakeTaskRepository()
      ..fetchPage = (page) => SuccessResponse(
        _tasks((page - 1) * 50, page < 3 ? 50 : 10),
        200,
        {'X-Pagination-Total-Pages': '3'},
      );

    final result = await fetchAllTaskPages(repo, 'done=false', {
      'filter_include_nulls': ['false'],
    });

    expect(result.isSuccessful, isTrue);
    expect(result.toSuccess().body, hasLength(110));
    expect(repo.requests.map((r) => r['page']!.single), ['1', '2', '3']);
    expect(repo.requests.first['filter_include_nulls'], ['false']);
    expect(repo.filters.toSet(), {'done=false'});
  });

  test('stops after one request when there is no pagination header', () async {
    final repo = FakeTaskRepository()
      ..fetchPage = (page) => SuccessResponse(_tasks(0, 5), 200, {});

    final result = await fetchAllTaskPages(repo, 'done=false');

    expect(result.toSuccess().body, hasLength(5));
    expect(repo.requests, hasLength(1));
  });

  test('returns the failing response if a later page fails', () async {
    final repo = FakeTaskRepository()
      ..fetchPage = (page) => page == 1
          ? SuccessResponse(_tasks(0, 50), 200, {
              'x-pagination-total-pages': '2',
            })
          : ErrorResponse(500, {}, {'message': 'boom'});

    final result = await fetchAllTaskPages(repo, 'done=false');

    expect(result.isError, isTrue);
    expect(repo.requests, hasLength(2));
  });
}
