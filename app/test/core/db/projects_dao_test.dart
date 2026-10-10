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
}
