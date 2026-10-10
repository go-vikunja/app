import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/online/online_project_repository.dart';

import '../../helpers/fake_read_client.dart';
import '../../helpers/sample_data.dart';

void main() {
  late FakeReadClient client;
  late OnlineProjectRepository repository;
  final work = sampleProject(id: 1, title: 'Work');
  final home = sampleProject(id: 2, title: 'Home');

  setUp(() {
    client = FakeReadClient();
    client.projects.all = [work, home];
    repository = OnlineProjectRepository(client);
  });

  tearDown(() => repository.dispose());

  test('the first subscription loads the projects once', () async {
    final seen = <List<Project>>[];
    repository.watchAll().listen(seen.add);
    repository.watchAll().listen(seen.add);
    await pumpEventQueue();

    expect(seen, [
      [work, home],
      [work, home],
    ]);
    expect(client.projects.listAllCalls, 1);
    expect(repository.find(2), home);
    expect(repository.find(3), isNull);
  });

  test('a later subscriber gets the cached list without a request', () async {
    repository.watchAll().listen((_) {});
    await pumpEventQueue();

    final seen = <List<Project>>[];
    repository.watchAll().listen(seen.add);
    await pumpEventQueue();

    expect(seen, [
      [work, home],
    ]);
    expect(client.projects.listAllCalls, 1);
  });

  test(
    'a failed first load is the stream error, and a retry recovers',
    () async {
      client.projects.onListAll = () async =>
          throw const NetworkFailure(NetworkProblem.unreachable);
      final seen = <List<Project>>[];
      final errors = <Object>[];
      repository.watchAll().listen(seen.add, onError: errors.add);
      await pumpEventQueue();
      expect(errors, [isA<NetworkFailure>()]);
      expect(seen, isEmpty);

      client.projects.onListAll = null;
      await repository.refresh();

      expect(seen, [
        [work, home],
      ]);
    },
  );

  test('a failed refresh throws and keeps the stale data', () async {
    final seen = <List<Project>>[];
    final errors = <Object>[];
    repository.watchAll().listen(seen.add, onError: errors.add);
    await pumpEventQueue();
    client.projects.onListAll = () async => throw const ServerFailure(502);

    await expectLater(repository.refresh(), throwsA(isA<ServerFailure>()));

    expect(errors, isEmpty);
    expect(seen, hasLength(1));
    expect(repository.find(1), work);
  });

  test('concurrent refreshes share one request', () async {
    final gate = Completer<List<Project>>();
    client.projects.onListAll = () => gate.future;

    final first = repository.refresh();
    final second = repository.refresh();
    gate.complete([work]);
    await Future.wait([first, second]);

    expect(client.projects.listAllCalls, 1);
    expect(repository.find(1), work);
  });

  test('a refresh replaces the list', () async {
    final seen = <List<Project>>[];
    repository.watchAll().listen(seen.add);
    await pumpEventQueue();
    client.projects.all = [home];

    await repository.refresh();

    expect(seen.last, [home]);
    expect(repository.find(1), isNull);
  });

  test('a result arriving after dispose is dropped', () async {
    final gate = Completer<List<Project>>();
    client.projects.onListAll = () => gate.future;
    final seen = <List<Project>>[];
    repository.watchAll().listen(seen.add);
    await pumpEventQueue();

    repository.dispose();
    gate.complete([work]);
    await pumpEventQueue();

    expect(seen, isEmpty);
    expect(repository.find(1), isNull);
  });
}
