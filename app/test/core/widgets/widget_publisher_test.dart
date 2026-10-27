import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/widgets/widget_catalog.dart';
import 'package:vikunja_mobile/core/widgets/widget_config.dart';
import 'package:vikunja_mobile/core/widgets/widget_publisher.dart';
import 'package:vikunja_mobile/core/widgets/widget_snapshot.dart';
import 'package:vikunja_mobile/core/widgets/widget_snapshot_builder.dart';

import '../../helpers/fake_timers.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';
import '../../helpers/widget_fakes.dart';

// The publisher with a build that names each snapshot after its kind and a
// title the test changes: what it writes, skips and redraws, and when.
void main() {
  const alice = '0123456789abcdef0123456789abcdef';
  const bob = 'fedcba9876543210fedcba9876543210';
  const account = WidgetAccount(
    id: alice,
    title: 'Alice',
    host: 'vikunja.example.com',
    isGuest: false,
    sessionEnded: false,
    supportsV2: true,
  );
  late AppDatabase db;
  late FakeWidgetHost host;
  late FakeTimers timers;
  late DateTime now;
  late String title;
  late WidgetAccount? registered;
  late List<Set<WidgetKind>> builds;

  setUp(() {
    db = testDatabase();
    host = FakeWidgetHost();
    timers = FakeTimers();
    now = DateTime.utc(2026, 10, 26, 9);
    title = 'Water the plants';
    registered = account;
    builds = [];
  });

  Future<WidgetBuild> build(
    WidgetAccount account,
    Set<WidgetKind> kinds, {
    required bool withCatalog,
  }) async {
    builds.add(kinds);
    return (
      snapshots: {
        for (final kind in kinds)
          snapshotKey(account.id, kind): WidgetSnapshot(
            key: snapshotKey(account.id, kind),
            accountId: account.id,
            state: account.state,
            title: '${kind.name}: $title',
            generatedAt: now,
            validUntil: DateTime.utc(2026, 10, 26, 23),
          ),
      },
      catalog: withCatalog
          ? WidgetCatalog(
              account: WidgetCatalogAccount(
                id: account.id,
                name: account.title,
                host: account.host,
                isGuest: false,
                supportsV2: true,
              ),
              generatedAt: now,
              lists: const [],
              canAddTasks: true,
            )
          : null,
    );
  }

  WidgetPublisher publisher({
    Set<WidgetKind> alwaysKinds = const {},
    bool refreshesAtValidity = false,
  }) {
    final publisher = WidgetPublisher(
      accountId: alice,
      db: db,
      host: host,
      account: () => registered,
      build: build,
      alwaysKinds: alwaysKinds,
      refreshesAtValidity: refreshesAtValidity,
      now: () => now,
      createTimer: timers.create,
    );
    addTearDown(publisher.dispose);
    return publisher;
  }

  void place(int id, String accountId, WidgetKind kind) =>
      host.placed[id] = WidgetConfig(accountId: accountId, kind: kind);

  test("writes the snapshots of the account's widgets and its catalog, and "
      'redraws them', () async {
    place(1, alice, const TodayKind());
    place(2, alice, const ProjectTasksKind(7));
    place(3, bob, const TodayKind());
    host.requested.add(
      const WidgetConfig(accountId: alice, kind: UpcomingKind(3)),
    );

    await publisher(alwaysKinds: {const QuickAddKind()}).publishNow();

    expect(host.snapshots.keys.toSet(), {
      '$alice.today',
      '$alice.project_7',
      '$alice.upcoming_3',
      '$alice.quick_add',
    });
    expect(host.snapshot('$alice.today')?.title, 'today: Water the plants');
    expect(host.catalogs.keys, [alice]);
    expect(host.updatedKeys.single, host.snapshots.keys.toSet());
  });

  test('writes nothing that did not change, then only what did', () async {
    place(1, alice, const TodayKind());
    place(2, alice, const FavoritesKind());
    final widgets = publisher();
    await widgets.publishNow();
    host.calls.clear();

    now = now.add(const Duration(minutes: 1));
    await widgets.publishNow();
    expect(host.calls, isEmpty, reason: 'only generatedAt changed');

    host.snapshots['$alice.favorites'] = 'written by another isolate';
    title = 'Water the plants twice';
    await widgets.publishNow();
    expect(host.calls, [
      'writeSnapshot $alice.today',
      'writeSnapshot $alice.favorites',
      'update $alice.favorites,$alice.today',
    ]);
  });

  test('writes a kind no widget shows yet once, when asked', () async {
    place(1, alice, const TodayKind());
    final widgets = publisher();

    await widgets.publishNow(also: {const UpcomingKind(7)});
    await widgets.publishNow();

    expect(builds, [
      {const TodayKind(), const UpcomingKind(7)},
      {const TodayKind()},
    ]);
    expect(host.snapshots.keys, contains('$alice.upcoming_7'));
  });

  test('a change publishes after a second of quiet, at the latest after '
      'three', () async {
    place(1, alice, const TodayKind());
    final widgets = publisher();
    Future<void> change() async {
      await db.tasksDao.upsertAll([
        sampleTask(id: 1, title: title),
      ], syncRunId: 'run');
      await pumpEventQueue();
    }

    await change();
    expect(timers.pendingWait, const Duration(seconds: 1));
    now = now.add(const Duration(milliseconds: 900));
    await change();
    expect(timers.pendingWait, const Duration(seconds: 1));
    now = now.add(const Duration(milliseconds: 1800));
    await change();
    expect(
      timers.pendingWait,
      const Duration(milliseconds: 300),
      reason: 'three seconds after the first change',
    );
    expect(host.snapshots, isEmpty);

    timers.fireNext();
    await pumpEventQueue();

    expect(host.writesOf('$alice.today'), 1);
    expect(timers.active, isEmpty);
    await change();
    expect(timers.pendingWait, const Duration(seconds: 1), reason: 'anew');
    await widgets.dispose();
  });

  test('a change reaches the widget within five seconds, also while '
      'changes keep coming', () async {
    place(1, alice, const TodayKind());
    publisher();
    final start = now;
    DateTime? firstWrite;
    for (var i = 0; i < 20; i++) {
      await db.tasksDao.upsertAll([
        sampleTask(id: 1, title: 'Edit $i'),
      ], syncRunId: 'run');
      await pumpEventQueue();
      final due = now.add(timers.pendingWait);
      final next = now.add(const Duration(milliseconds: 400));
      if (!due.isAfter(next)) {
        now = due;
        timers.fireNext();
        await pumpEventQueue();
        if (host.writesOf('$alice.today') > 0) firstWrite ??= now;
      }
      now = next;
    }

    expect(
      firstWrite!.difference(start),
      lessThanOrEqualTo(const Duration(seconds: 3)),
    );
  });

  test('builds once more when asked during a run', () async {
    place(1, alice, const TodayKind());
    final widgets = publisher();

    final first = widgets.publishNow();
    final second = widgets.publishNow();
    await Future.wait([first, second]);

    expect(builds, hasLength(2));
  });

  test('writes nothing once the account is gone, or after dispose', () async {
    place(1, alice, const TodayKind());
    final widgets = publisher();
    registered = null;
    await widgets.publishNow();
    expect(host.calls, isEmpty);

    registered = account;
    await widgets.dispose();
    await widgets.publishNow();
    expect(host.calls, isEmpty);
  });

  test('previews a kind without writing', () async {
    final preview = await publisher().preview(const UpcomingKind(14));

    expect(preview?.key, '$alice.upcoming_14');
    expect(host.calls, isEmpty);
  });

  test('in the app it publishes again when the snapshots go stale', () async {
    place(1, alice, const TodayKind());
    await publisher(refreshesAtValidity: true).publishNow();

    expect(timers.pendingWait, const Duration(hours: 14, seconds: 1));
    now = DateTime.utc(2026, 10, 26, 23, 0, 1);
    title = 'A new day';
    timers.fireNext();
    await pumpEventQueue();

    expect(host.snapshot('$alice.today')?.title, 'today: A new day');
  });

  test('sign-out deletes the account, and its widgets say it was '
      'removed', () async {
    place(1, alice, const TodayKind());
    place(2, bob, const TodayKind());
    final widgets = publisher(alwaysKinds: {const QuickAddKind()});
    final publishers = WidgetPublishers(
      host: host,
      removedSnapshot: (key, accountId) => WidgetSnapshot(
        key: key,
        accountId: accountId,
        state: WidgetSnapshotState.accountRemoved,
        title: 'Account removed',
        generatedAt: now,
        validUntil: now,
      ),
    )..register(widgets);
    await widgets.publishNow();
    host.snapshots['$bob.today'] = 'bob';
    host.calls.clear();

    await publishers.wipe(alice);

    expect(host.calls.first, 'deleteForAccount $alice');
    expect(host.catalogs, isEmpty);
    expect(host.snapshots['$bob.today'], 'bob');
    for (final key in ['$alice.today', '$alice.quick_add']) {
      expect(host.snapshot(key)?.state, WidgetSnapshotState.accountRemoved);
    }
    expect(host.calls.last, 'update $alice.quick_add,$alice.today');
    expect(publishers.find(alice), isNull);
    await widgets.publishNow();
    expect(
      host.snapshot('$alice.today')?.state,
      WidgetSnapshotState.accountRemoved,
      reason: 'the disposed publisher writes no more',
    );
  });

  test('sign-out in an isolate without a publisher still covers the placed '
      'widgets', () async {
    place(1, alice, const ProjectTasksKind(4));
    final publishers = WidgetPublishers(
      host: host,
      removedSnapshot: (key, accountId) => WidgetSnapshot(
        key: key,
        accountId: accountId,
        state: WidgetSnapshotState.accountRemoved,
        title: 'Account removed',
        generatedAt: now,
        validUntil: now,
      ),
    );

    await publishers.wipe(alice);

    expect(host.snapshots.keys, ['$alice.project_4']);
    expect(host.updatedKeys.single, {'$alice.project_4'});
  });

  test('a host that fails propagates to publishNow and is only logged by '
      'publishQuietly', () async {
    place(1, alice, const TodayKind());
    final widgets = publisher();
    host.failure = Exception('disk full');

    await expectLater(widgets.publishNow(), throwsException);
    widgets.publishQuietly();
    await pumpEventQueue();

    host.failure = null;
    await widgets.publishNow();
    expect(host.writesOf('$alice.today'), 1);
  });
}
