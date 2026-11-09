import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';

import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  const alice = User(id: 7, username: 'alice', name: 'Alice');
  const listView = ProjectView(
    id: 11,
    projectId: 1,
    title: 'List',
    kind: ProjectViewKind.list,
    filter: ViewFilter(filter: 'done = false'),
  );
  const kanban = ProjectView(
    id: 12,
    projectId: 1,
    title: 'Kanban',
    kind: ProjectViewKind.kanban,
    position: 1,
    bucketConfigurationMode: BucketConfigurationMode.manual,
    defaultBucketId: 3,
    doneBucketId: 4,
  );
  const work = Project(
    id: 1,
    title: 'Work',
    position: 2,
    owner: alice,
    views: [kanban, listView],
  );

  setUp(() => db = testDatabase());

  test(
    'stores projects with their views and owner, ordered by position',
    () async {
      await db.projectsDao.upsertAll([
        work,
        sampleProject(id: 2, title: 'Home', position: 1),
        sampleProject(id: 3, title: 'Archive', archived: true, position: 3),
      ]);

      final all = await db.projectsDao.loadAll();

      expect(all.map((p) => p.id), [2, 1, 3]);
      final found = all[1];
      expect(found, work);
      expect(found.owner, alice);
      expect(found.views.map((v) => v.id), [11, 12]);
      expect(found.views.first.filter?.filter, 'done = false');
      expect(found.views.last.doneBucketId, 4);
      expect(all.last.isArchived, isTrue);
    },
  );

  test('pseudo projects are skipped', () async {
    await db.projectsDao.upsertAll([
      work,
      const Project(id: Project.favoritesId, title: 'Favorites'),
      const Project(id: -2, title: 'Saved filter'),
    ]);

    expect((await db.projectsDao.loadAll()).map((p) => p.id), [1]);
  });

  test('an upsert replaces the views', () async {
    await db.projectsDao.upsertAll([work]);

    await db.projectsDao.upsertAll([
      const Project(id: 1, title: 'Work', views: [listView]),
    ]);

    final found = (await db.projectsDao.loadAll()).single;
    expect(found.views, [listView]);
    expect(found.owner, isNull);
  });

  test('purging removes the project and its views', () async {
    await db.projectsDao.upsertAll([work, sampleProject(id: 2, title: 'Home')]);

    final purged = await db.projectsDao.purgeNotIn([2]);

    expect(purged, 1);
    expect((await db.projectsDao.loadAll()).map((p) => p.id), [2]);
    expect(await db.select(db.projectViews).get(), isEmpty);
  });

  test('a single view loads by id', () async {
    await db.projectsDao.upsertAll([work]);

    final found = await db.projectsDao.loadView(12);

    expect(found, kanban);
    expect(found?.defaultBucketId, 3);
    expect(found?.bucketConfigurationMode, BucketConfigurationMode.manual);
    expect(await db.projectsDao.loadView(99), isNull);
  });

  test("a view's bucket change writes only the given ids and reaches the "
      'stream', () async {
    await db.projectsDao.upsertAll([work]);
    final seen = <List<Project>>[];
    final subscription = db.projectsDao.watchAll().listen(seen.add);
    addTearDown(subscription.cancel);
    await pumpEventQueue();

    await db.projectsDao.setViewBuckets(12, doneBucketId: 0);
    await pumpEventQueue();

    var found = seen.last.single.views.firstWhere((v) => v.id == 12);
    expect(found.doneBucketId, 0);
    expect(found.defaultBucketId, 3);
    expect(found.title, 'Kanban');
    expect(found.kind, ProjectViewKind.kanban);
    expect(found.position, 1);

    await db.projectsDao.setViewBuckets(12, defaultBucketId: 5);
    await db.projectsDao.setViewBuckets(11);
    await pumpEventQueue();

    found = seen.last.single.views.firstWhere((v) => v.id == 12);
    expect((found.doneBucketId, found.defaultBucketId), (0, 5));
    expect(
      seen.last.single.views.firstWhere((v) => v.id == 11).filter?.filter,
      'done = false',
    );
  });

  test("a project's move writes only its position and parent and reaches "
      'the stream', () async {
    await db.projectsDao.upsertAll([
      work,
      sampleProject(id: 2, title: 'Home', position: 1),
    ]);
    final seen = <List<Project>>[];
    final subscription = db.projectsDao.watchAll().listen(seen.add);
    addTearDown(subscription.cancel);
    await pumpEventQueue();

    await db.projectsDao.moveProject(1, position: 0.5, parentProjectId: 2);
    await pumpEventQueue();

    expect(seen.last.map((p) => p.id), [1, 2]);
    expect(
      seen.last.first,
      movedProject(work, position: 0.5, parentProjectId: 2),
    );
    expect(seen.last.first.owner, alice);
    expect(seen.last.first.views.map((v) => v.id), [11, 12]);
  });

  test('the stream follows projects, views and owners', () async {
    final seen = <List<Project>>[];
    final subscription = db.projectsDao.watchAll().listen(seen.add);
    addTearDown(subscription.cancel);
    await pumpEventQueue();
    expect(seen, [isEmpty]);

    await db.projectsDao.upsertAll([work]);
    await pumpEventQueue();
    expect(seen.last.single.owner?.name, 'Alice');

    await db.usersDao.upsertAll(const [
      User(id: 7, username: 'alice', name: 'A.'),
    ]);
    await pumpEventQueue();
    expect(seen.last.single.owner?.name, 'A.');

    await db.projectsDao.purgeNotIn(const []);
    await pumpEventQueue();
    expect(seen.last, isEmpty);
  });

  group('the subscription that covers a project', () {
    const ownRow = Subscription(
      entity: SubscriptionEntity.project,
      entityId: 1,
    );
    const parentRow = Subscription(
      entity: SubscriptionEntity.project,
      entityId: 2,
    );

    test('an upsert writes it and a load brings it back', () async {
      await db.projectsDao.upsertAll([
        work.copyWith(subscription: ownRow),
        sampleProject(
          id: 3,
          title: 'Child',
          parent: 2,
        ).copyWith(subscription: parentRow),
        sampleProject(id: 4, title: 'Not followed'),
      ]);

      final all = {
        for (final project in await db.projectsDao.loadAll())
          project.id: project.subscription,
      };
      expect(all, {1: ownRow, 3: parentRow, 4: null});
      expect((await db.projectsDao.loadProject(3))!.subscription, parentRow);

      await db.projectsDao.upsertAll([work]);
      expect((await db.projectsDao.loadProject(1))!.subscription, isNull);
    });

    test('stored on its own: set, changed and cleared; a task subscription '
        'counts as none; an unknown project stays unknown', () async {
      await db.projectsDao.upsertAll([work]);
      final dao = db.projectsDao;

      await dao.storeSubscription(1, ownRow);
      expect((await dao.loadProject(1))!.subscription, ownRow);
      await dao.storeSubscription(1, parentRow);
      expect((await dao.loadProject(1))!.subscription, parentRow);
      await dao.storeSubscription(
        1,
        const Subscription(entity: SubscriptionEntity.task, entityId: 9),
      );
      expect((await dao.loadProject(1))!.subscription, isNull);
      await dao.storeSubscription(1, ownRow);
      await dao.storeSubscription(1, null);
      expect((await dao.loadProject(1))!.subscription, isNull);

      await dao.storeSubscription(99, ownRow);
      expect(await dao.loadProject(99), isNull);
      expect((await dao.loadProject(1))!.title, 'Work');
    });

    test('the projects below that were covered through it get the same; '
        'those a nearer project covers, or none, keep theirs', () async {
      Subscription via(int id) =>
          Subscription(entity: SubscriptionEntity.project, entityId: id);
      Project child(int id, int parent, {int? coveredBy}) => sampleProject(
        id: id,
        title: 'Child $id',
        parent: parent,
      ).copyWith(subscription: coveredBy == null ? null : via(coveredBy));
      await db.projectsDao.upsertAll([
        child(20, 0, coveredBy: 20),
        child(1, 20, coveredBy: 1),
        child(2, 1, coveredBy: 1),
        child(3, 2, coveredBy: 1),
        child(4, 1, coveredBy: 4),
        child(5, 4, coveredBy: 4),
        child(6, 1),
        child(7, 20, coveredBy: 20),
        child(8, 7, coveredBy: 20),
        child(9, 8, coveredBy: 9),
        child(30, 0, coveredBy: 30),
      ]);
      Future<Map<int, int?>> stored() async => {
        for (final project in await db.projectsDao.loadAll())
          project.id: project.subscription?.entityId,
      };

      // 1 unfollowed: its opt-out, as 20 still covers it, hides 1 for all
      // that inherited through it.
      await db.projectsDao.storeSubscription(1, null);
      // 7, covered by 20 and unfollowed: an opt-out on 7 hides 20 for 8.
      await db.projectsDao.storeSubscription(7, null);

      expect(await stored(), {
        20: 20,
        1: null,
        2: null,
        3: null,
        4: 4,
        5: 4,
        6: null,
        7: null,
        8: null,
        9: 9,
        30: 30,
      });

      // Followed again: 2 and 3 may have an opt-out of their own, which only
      // the next project list can tell.
      await db.projectsDao.storeSubscription(1, via(1));
      expect(await stored(), containsPair(1, 1));
      expect(await stored(), containsPair(2, null));
      expect(await stored(), containsPair(3, null));
    });

    test('written only when it changes', () async {
      await db.projectsDao.upsertAll([work]);
      var writes = 0;
      final updates = db
          .tableUpdates(TableUpdateQuery.onTable(db.projects))
          .listen((_) => writes++);
      addTearDown(updates.cancel);
      final dao = db.projectsDao;

      await dao.storeSubscription(1, null);
      await pumpEventQueue();
      expect(writes, 0);
      await dao.storeSubscription(1, ownRow);
      await pumpEventQueue();
      expect(writes, 1);
      await dao.storeSubscription(1, ownRow);
      await pumpEventQueue();
      expect(writes, 1);
      await dao.storeSubscription(1, null);
      await pumpEventQueue();
      expect(writes, 2);
    });
  });
}
