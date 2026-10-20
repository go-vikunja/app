import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/local/local_project_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_saved_filter_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/sync/saved_filters.dart';

import '../../helpers/fake_write_client.dart';
import '../../helpers/recording_sync_engine.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late RecordingSyncEngine sync;
  late FakeWriteClient server;
  late LocalSavedFilterRepository repository;
  final now = DateTime.utc(2026, 10, 20, 12, 0, 0, 250);
  final listed = DateTime.utc(2026, 10, 19, 9);
  const open = ViewFilter(filter: 'done = false', includeNulls: true);

  setUp(() async {
    db = testDatabase();
    sync = RecordingSyncEngine();
    server = FakeWriteClient(clock: () => now);
    repository = LocalSavedFilterRepository(db, sync, server);
    server.serverSavedFilters[13] = SavedFilter(
      id: 13,
      title: 'My Open Tasks',
      filter: const ViewFilter(filter: 'done = false && assignees = alice'),
      updated: listed,
    );
    await storeSavedFilters(db, [
      SavedFilterRef(projectId: -14, title: 'My Open Tasks', updated: listed),
    ]);
  });

  Future<List<SavedFilterRef>> stored() =>
      LocalProjectRepository(db, sync, server).watchSavedFilters().first;

  test('a new saved filter is stored with its definition at once and a sync '
      'follows', () async {
    final id = await repository.create(
      const SavedFilterDraft(
        title: ' Open ',
        description: 'Everything open',
        filter: open,
        isFavorite: true,
      ),
    );
    await pumpEventQueue();

    expect(server.requests, ['create filter Open']);
    expect(id, -301);
    final created = (await stored()).firstWhere((f) => f.projectId == id);
    expect(created.title, 'Open');
    expect(created.description, 'Everything open');
    expect(created.isFavorite, isTrue);
    expect(created.updated, now);
    expect(
      created.definition,
      SavedFilterDefinition(filter: open, updated: now),
    );
    expect(needsDefinition(created), isFalse);
    expect(sync.refreshAfterWriteCalls, 1);
  });

  test('an update replaces the stored entry with the answer', () async {
    await repository.update(
      -14,
      const SavedFilterDraft(title: 'Mine', filter: open),
    );

    expect(server.requests, ['update filter 13 Mine']);
    expect(await stored(), [
      SavedFilterRef(
        projectId: -14,
        title: 'Mine',
        updated: now,
        definition: SavedFilterDefinition(filter: open, updated: now),
      ),
    ]);
    await pumpEventQueue();
    expect(sync.refreshAfterWriteCalls, 1);
  });

  test('the favourite changes only the flag', () async {
    await repository.setFavorite(-14, favorite: true);

    expect(server.requests, ['favorite filter 13 true']);
    final filter = (await stored()).single;
    expect(filter.isFavorite, isTrue);
    expect(
      filter.definition?.filter.filter,
      'done = false && assignees = alice',
    );
  });

  test('a delete takes the filter and its downloads away', () async {
    await db.listSnapshotsDao.replace(savedFilterSnapshotKey(-14), {
      1: 0,
    }, loadedAt: now);
    await db.listSnapshotsDao.replace(overviewSnapshotKey(-14), {
      1: 0,
    }, loadedAt: now);
    await db.listSnapshotsDao.replace(savedFilterSnapshotKey(-140), {
      1: 0,
    }, loadedAt: now);

    await repository.delete(-14);

    expect(server.requests, ['delete filter 13']);
    expect(await stored(), isEmpty);
    expect(
      (await db.listSnapshotsDao.load(savedFilterSnapshotKey(-14))).loadedAt,
      isNull,
    );
    expect(
      (await db.listSnapshotsDao.load(overviewSnapshotKey(-14))).loadedAt,
      isNull,
    );
    expect(
      (await db.listSnapshotsDao.load(savedFilterSnapshotKey(-140))).loadedAt,
      now,
    );
  });

  test('a read stores the definition of a listed filter, and only of '
      'one', () async {
    final read = await repository.read(-14);

    expect(read.filter.filter, 'done = false && assignees = alice');
    final filter = (await stored()).single;
    expect(filter.definition?.filter, read.filter);
    expect(filter.updated, listed);

    server.serverSavedFilters[20] = const SavedFilter(
      id: 20,
      title: 'Not listed',
      filter: open,
    );
    await repository.read(-21);
    expect((await stored()).map((f) => f.projectId), [-14]);
  });

  test('a blank title is refused before any request', () async {
    await expectLater(
      repository.create(const SavedFilterDraft(title: '  ', filter: open)),
      throwsArgumentError,
    );
    await expectLater(
      repository.update(-14, const SavedFilterDraft(title: '', filter: open)),
      throwsArgumentError,
    );
    expect(server.requests, isEmpty);
  });

  test('an id that is not a saved filter is refused', () async {
    await expectLater(
      repository.setFavorite(-1, favorite: true),
      throwsArgumentError,
    );
    await expectLater(repository.delete(5), throwsArgumentError);
  });

  test('a refusal changes nothing here and runs no sync', () async {
    server.refusedFilters['done = yes'] = const DomainError(400, code: 4019);
    final before = await stored();

    await expectLater(
      repository.update(
        -14,
        const SavedFilterDraft(
          title: 'Broken',
          filter: ViewFilter(filter: 'done = yes'),
        ),
      ),
      throwsA(isA<DomainError>().having((f) => f.code, 'code', 4019)),
    );
    await expectLater(
      repository.setFavorite(-99, favorite: true),
      throwsA(isA<NotFound>().having((f) => f.code, 'code', 11001)),
    );
    server.beforeRequest = (_) async =>
        throw const NetworkFailure(NetworkProblem.unreachable);
    await expectLater(repository.delete(-14), throwsA(isA<NetworkFailure>()));

    expect(await stored(), before);
    await pumpEventQueue();
    expect(sync.refreshAfterWriteCalls, 0);
  });

  test('a failing sync after the write is swallowed', () async {
    sync.error = const NetworkFailure(NetworkProblem.unreachable);

    await repository.setFavorite(-14, favorite: true);
    await pumpEventQueue();

    expect((await stored()).single.isFavorite, isTrue);
  });
}
