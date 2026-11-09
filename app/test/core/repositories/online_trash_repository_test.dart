import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/online/online_trash_repository.dart';

import '../../helpers/sample_data.dart';
import '../../helpers/trash_fakes.dart';

void main() {
  late FakeTrashPort port;
  late OnlineTrashRepository repository;
  final deletedAt = DateTime.utc(2026, 11, 2, 8);
  const kim = User(id: 7, username: 'kim');

  setUp(() {
    port = FakeTrashPort()
      ..trashedTasks = [
        TrashedTask(
          task: sampleTask(id: 41, title: 'Seeds', projectId: 5),
          deletedAt: deletedAt,
          deletedBy: kim,
          canDeletePermanently: true,
        ),
        TrashedTask(
          task: sampleTask(id: 42, title: 'Water', projectId: 6),
          deletedAt: deletedAt,
        ),
      ]
      ..trashedProjects = [
        TrashedProject(
          project: sampleProject(id: 5, title: 'Garden'),
          deletedAt: deletedAt,
          subprojects: const [
            TrashedSubproject(
              id: 6,
              title: 'Beds',
              parentProjectId: 5,
              depth: 1,
            ),
          ],
        ),
      ]
      ..taskCountAnswer = const TrashCount(total: 1, byOthers: 1)
      ..projectCountAnswer = const TrashCount(total: 1, byOthers: 0);
    repository = OnlineTrashRepository(port: port);
  });

  test('the lists and counts are the port answers', () async {
    expect((await repository.tasks()).map((item) => item.task.id), [41, 42]);
    expect((await repository.tasks()).first.deletedBy, kim);
    expect(
      (await repository.projects()).single.subprojects.single.title,
      'Beds',
    );
    expect(
      await repository.taskCount(),
      const TrashCount(total: 1, byOthers: 1),
    );
    expect(
      await repository.projectCount(),
      const TrashCount(total: 1, byOthers: 0),
    );
    expect(port.calls, [
      'tasks',
      'tasks',
      'projects',
      'taskCount',
      'projectCount',
    ]);
  });

  test('emptying includes what other people moved there', () async {
    await repository.emptyTasks();
    await repository.emptyProjects();

    expect(port.calls, [
      'emptyTasks includeOthers: true',
      'emptyProjects includeOthers: true',
    ]);
    expect(port.trashedTasks.map((item) => item.task.id), [42]);
    expect(port.trashedProjects, isEmpty);
  });

  test('deleting forever passes the id through', () async {
    await repository.deleteTaskForever(41);
    await repository.deleteProjectForever(5);

    expect(port.calls, ['deleteTaskForever 41', 'deleteProjectForever 5']);
    expect(port.trashedTasks.map((item) => item.task.id), [42]);
    expect(port.trashedProjects, isEmpty);
  });

  test('a failure passes through', () async {
    port.failures['tasks'] = const NetworkFailure(NetworkProblem.unreachable);
    port.failures['deleteTaskForever'] = const Forbidden();

    await expectLater(repository.tasks(), throwsA(isA<NetworkFailure>()));
    await expectLater(
      repository.deleteTaskForever(41),
      throwsA(isA<Forbidden>()),
    );
    expect(port.trashedTasks, hasLength(2));
  });
}
