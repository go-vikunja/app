import 'package:flutter/widgets.dart' show Color, Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/legible_color.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/settings/user_settings_json.dart';
import 'package:vikunja_mobile/core/sync/saved_filters.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/time/moments.dart';
import 'package:vikunja_mobile/core/widgets/widget_catalog.dart';
import 'package:vikunja_mobile/core/widgets/widget_config.dart';
import 'package:vikunja_mobile/core/widgets/widget_snapshot.dart';
import 'package:vikunja_mobile/core/widgets/widget_snapshot_builder.dart';
import 'package:vikunja_mobile/core/widgets/widget_texts.dart';
import 'package:vikunja_mobile/features/tasks/application/display_settings.dart';

import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';

// The builder over a seeded in-memory database, in the device's local time
// (the runs here are in Europe/Berlin, whose clocks went back on
// 2026-10-25).
void main() {
  const accountId = '0123456789abcdef0123456789abcdef';
  const alice = WidgetAccount(
    id: accountId,
    title: 'Alice',
    host: 'vikunja.example.com',
    isGuest: false,
    sessionEnded: false,
    supportsV2: true,
  );
  final now = DateTime(2026, 10, 26, 10);
  const garden = Label(id: 5, title: 'Garden', hexColor: '#4caf50');
  late AppDatabase db;
  late WidgetTexts texts;

  setUp(() async {
    db = testDatabase();
    texts = await WidgetTexts.load(
      lookupAppLocalizations(const Locale('en')),
      alwaysUse24HourFormat: true,
    );
    await db.projectsDao.upsertAll([
      sampleProject(
        id: 1,
        title: 'Inbox',
        hexColor: '1973FF',
        views: const [
          ProjectView(
            id: 11,
            projectId: 1,
            title: 'Kanban',
            kind: ProjectViewKind.kanban,
          ),
          ProjectView(
            id: 12,
            projectId: 1,
            title: 'List',
            kind: ProjectViewKind.list,
            position: 1,
            filter: ViewFilter(filter: 'done = false'),
          ),
        ],
      ).copyWith(maxPermission: Permission.admin),
      sampleProject(
        id: 2,
        title: 'Shared',
      ).copyWith(maxPermission: Permission.read),
      sampleProject(id: 3, title: 'Old', archived: true),
    ]);
    await db.labelsDao.upsertAll([garden]);
    await db.tasksDao.upsertAll([
      sampleTask(id: 1, title: 'Yesterday', due: DateTime(2026, 10, 25, 9)),
      sampleTask(
        id: 2,
        title: 'This afternoon',
        due: DateTime(2026, 10, 26, 15),
        priority: TaskPriority.high,
      ),
      sampleTask(
        id: 3,
        title: 'Tomorrow, read only',
        projectId: 2,
        due: DateTime(2026, 10, 27, 9),
      ),
      sampleTask(
        id: 4,
        title: 'Saturday',
        due: DateTime(2026, 10, 31, 18),
        favorite: true,
      ),
      sampleTask(id: 5, title: 'Weeding', labels: const [garden]),
      sampleTask(
        id: 6,
        title: 'Archived',
        projectId: 3,
        due: DateTime(2026, 10, 26, 8),
      ),
      sampleTask(
        id: 7,
        title: 'Done already',
        due: DateTime(2026, 10, 26, 9),
        done: true,
      ),
    ], syncRunId: 'run');
  });

  Future<Map<String, WidgetSnapshot>> build(
    Set<WidgetKind> kinds, {
    WidgetAccount account = alice,
    WidgetTexts? using,
    String? linkKey,
  }) async => (await WidgetSnapshotBuilder(
    db: db,
    texts: using ?? texts,
    linkKey: linkKey,
    now: () => now,
  ).build(account, kinds, withCatalog: false)).snapshots;

  Future<WidgetSnapshot> one(
    WidgetKind kind, {
    WidgetAccount account = alice,
    WidgetTexts? using,
  }) async =>
      (await build({kind}, account: account, using: using)).values.single;

  test("every link carries the install's link key", () async {
    const key = 'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8';
    const ended = WidgetAccount(
      id: accountId,
      title: 'Alice',
      host: 'vikunja.example.com',
      isGuest: false,
      sessionEnded: true,
      supportsV2: true,
    );
    final snapshots = [
      ...(await build({
        const TodayKind(),
        const ProjectTasksKind(1),
        const ProjectTasksKind(99),
        const QuickAddKind(),
      }, linkKey: key)).values,
      ...(await build(
        {const TodayKind()},
        account: ended,
        linkKey: key,
      )).values,
    ];
    final links = [
      for (final snapshot in snapshots) ...[
        ?snapshot.link,
        ?snapshot.newTaskLink,
        ?snapshot.messageLink,
        for (final row in snapshot.rows) row.link,
      ],
    ];

    expect(links, hasLength(greaterThan(6)));
    for (final link in links) {
      expect(Uri.parse(link).queryParameters['k'], key, reason: link);
    }
  });

  List<String> titles(WidgetSnapshot snapshot) => [
    for (final row in snapshot.rows) row.title,
  ];

  test("a row's project colour is drawn as the app draws its folders: "
      'only its lightness moved to stand out from each background', () async {
    await db.projectsDao.upsertAll([
      sampleProject(
        id: 1,
        title: 'Inbox',
        hexColor: '6A1B9A',
      ).copyWith(maxPermission: Permission.admin),
    ]);

    final [_, afternoon] = (await one(const TodayKind())).rows;
    Color drawn(String? hex) => Color(0xFF000000 | int.parse(hex!, radix: 16));
    expect(afternoon.projectColor, '6a1b9a');
    expect(afternoon.projectColorLight, '6a1b9a');
    expect(afternoon.projectColorDark, isNot('6a1b9a'));
    expect(
      contrastRatio(drawn(afternoon.projectColorDark), const Color(0xFF0E141C)),
      greaterThanOrEqualTo(3),
    );
  });

  group('Today', () {
    test('lists the overdue and the due today, like the Overview', () async {
      final today = await one(const TodayKind());

      expect(today.key, '$accountId.today');
      expect(today.state, WidgetSnapshotState.ok);
      expect(today.title, 'Today');
      expect(titles(today), ['Yesterday', 'This afternoon']);
      final [yesterday, afternoon] = today.rows;
      expect(yesterday.dueLabel, 'Yesterday, 09:00');
      expect(yesterday.absoluteDueLabel, 'Oct 25, 09:00');
      expect(yesterday.tone, WidgetDueTone.overdue);
      expect(afternoon.dueLabel, 'Today, 15:00');
      expect(afternoon.absoluteDueLabel, 'Oct 26, 15:00');
      expect(afternoon.tone, WidgetDueTone.today);
      expect(afternoon.priorityLabel, 'High');
      expect(afternoon.priorityLevel, 3);
      expect(afternoon.projectTitle, 'Inbox');
      expect(afternoon.projectColor, '1973ff');
      expect(afternoon.projectColorLight, '1973ff');
      expect(afternoon.projectColorDark, '1973ff');
      expect(afternoon.canDone, isTrue);
      expect(
        afternoon.semanticsLabel,
        'This afternoon\nInbox\nDue Today, 15:00\nPriority: High',
      );
      // Past midnight, where the iOS extension shows the dates, the
      // afternoon has passed.
      expect(
        afternoon.absoluteSemanticsLabel,
        'This afternoon\nInbox\nOverdue, due Oct 26, 15:00\nPriority: High',
      );
      expect(
        yesterday.absoluteSemanticsLabel,
        'Yesterday\nInbox\nOverdue, due Oct 25, 09:00',
      );
      expect(afternoon.doneLabel, 'Mark “This afternoon” as done');
      expect(
        afternoon.link,
        'vikunja-io.vikunja.app://widget/task/2?account=$accountId',
      );
      expect(today.total, 2);
      expect(today.moreLabel, isNull);
      expect(today.countLabel, '2 tasks');
      expect(today.changesAt, [DateTime(2026, 10, 26, 15).toUtc()]);
      expect(today.validUntil, DateTime(2026, 10, 27));
      expect(
        today.link,
        'vikunja-io.vikunja.app://widget/list?account=$accountId'
        '&kind=today',
      );
      expect(
        today.newTaskLink,
        'vikunja-io.vikunja.app://widget/new-task?account=$accountId',
      );
      expect(today.message, isNull);
      expect(today.empty?.title, 'All done');
      expect(today.staleNotice, 'Open Vikunja to update');
    });

    test('moves to the next day at local midnight', () async {
      final beforeMidnight = DateTime(2026, 10, 26, 23, 59);
      final atMidnight = DateTime(2026, 10, 27);
      Future<List<String>> todayAt(DateTime at) async => titles(
        (await WidgetSnapshotBuilder(db: db, texts: texts, now: () => at).build(
          alice,
          {const TodayKind()},
          withCatalog: false,
        )).snapshots.values.single,
      );

      expect(await todayAt(beforeMidnight), ['Yesterday', 'This afternoon']);
      expect(await todayAt(atMidnight), [
        'Yesterday',
        'This afternoon',
        'Tomorrow, read only',
      ]);
    });

    test("follows the Overview's saved filter, evaluated here", () async {
      await db.syncStateDao.write({
        SyncStateKeys.userSettings: encodeUserSettings(
          const UserSettings(filterIdUsedOnOverview: -2),
        ),
        SyncStateKeys.savedFilters: encodeSavedFilters([
          const SavedFilterRef(
            projectId: -2,
            title: 'Important',
            definition: SavedFilterDefinition(
              filter: ViewFilter(filter: 'priority >= 3'),
            ),
          ),
        ]),
      });

      expect(titles(await one(const TodayKind())), ['This afternoon']);
    });
  });

  test('Upcoming pins the overdue and covers its days', () async {
    final three = await one(const UpcomingKind(3));
    final fourteen = await one(const UpcomingKind(14));

    expect(three.title, 'Next 3 days');
    expect(titles(three), [
      'Yesterday',
      'This afternoon',
      'Tomorrow, read only',
    ]);
    expect(three.rows[2].dueLabel, 'Tomorrow, 09:00');
    expect(three.rows[2].absoluteDueLabel, 'Oct 27, 09:00');
    expect(three.rows[2].tone, WidgetDueTone.later);
    expect(titles(fourteen).last, 'Saturday');
    expect(fourteen.rows.last.dueLabel, 'Sat, 18:00');
    expect(fourteen.rows.last.absoluteDueLabel, 'Oct 31, 18:00');
    // Days, not today alone: the range's neutral text, not the cheerful one.
    expect(three.empty, const WidgetText('Nothing due in this range'));
  });

  test('Overdue lists only what is overdue, outside archived '
      'projects', () async {
    final overdue = await one(const OverdueKind());

    expect(overdue.title, 'Overdue');
    expect(titles(overdue), ['Yesterday']);
    expect(overdue.empty?.title, 'Nothing overdue');
  });

  group('a list whose tasks join by the clock is valid until the next '
      'joins, its count too', () {
    Future<WidgetSnapshot> at(
      DateTime at,
      WidgetKind kind, {
      bool showTaskTitles = true,
      bool joinsEndValidity = true,
    }) async => (await WidgetSnapshotBuilder(
      db: db,
      texts: texts,
      showTaskTitles: showTaskTitles,
      joinsEndValidity: joinsEndValidity,
      now: () => at,
    ).build(alice, {kind}, withCatalog: false)).snapshots.values.single;

    test('Overdue: until the next open task falls due', () async {
      final overdue = await at(now, const OverdueKind());
      final hidden = await at(now, const OverdueKind(), showTaskTitles: false);

      expect(overdue.validUntil.toUtc(), DateTime(2026, 10, 26, 15).toUtc());
      expect(hidden.validUntil, overdue.validUntil);
      expect(titles(await at(overdue.validUntil, const OverdueKind())), [
        'Yesterday',
        'This afternoon',
      ]);
      expect(
        (await at(
          overdue.validUntil,
          const OverdueKind(),
          showTaskTitles: false,
        )).total,
        2,
      );
    });

    test('Upcoming: until the next task comes within its days, on the '
        'wall clock across a change of the clocks', () async {
      await db.tasksDao.upsertAll([
        sampleTask(
          id: 8,
          title: 'Tuesday afternoon',
          due: DateTime(2026, 10, 27, 15),
        ),
      ], syncRunId: 'run');
      // Before the clocks went back on the 25th.
      final saturday = DateTime(2026, 10, 24, 10);
      const three = UpcomingKind(3);

      final upcoming = await at(saturday, three);
      final hidden = await at(saturday, three, showTaskTitles: false);

      expect(upcoming.validUntil.toLocal(), DateTime(2026, 10, 24, 15));
      expect(hidden.validUntil, upcoming.validUntil);
      expect(titles(upcoming), isNot(contains('Tuesday afternoon')));
      final justBefore = upcoming.validUntil.subtract(
        const Duration(seconds: 1),
      );
      expect(
        titles(await at(justBefore, three)),
        isNot(contains('Tuesday afternoon')),
      );
      final justAfter = upcoming.validUntil.add(const Duration(seconds: 1));
      expect(titles(await at(justAfter, three)), contains('Tuesday afternoon'));
    });

    test('the others until midnight', () async {
      for (final kind in [
        const TodayKind(),
        const ProjectTasksKind(1),
        const FavoritesKind(),
      ]) {
        expect((await at(now, kind)).validUntil, DateTime(2026, 10, 27));
      }
    });

    test('until midnight where nothing writes it again at a join (iOS), '
        'which would draw it as stale until then', () async {
      for (final kind in [const OverdueKind(), const UpcomingKind(3)]) {
        expect(
          (await at(now, kind, joinsEndValidity: false)).validUntil,
          DateTime(2026, 10, 27),
        );
      }
    });
  });

  group('Project', () {
    test("its first list view's open top-level tasks, with its own new "
        'task link', () async {
      final inbox = await one(const ProjectTasksKind(1));

      expect(inbox.title, 'Inbox');
      expect(titles(inbox).toSet(), {
        'Yesterday',
        'This afternoon',
        'Saturday',
        'Weeding',
      });
      expect(inbox.rows.every((row) => row.projectTitle == null), isTrue);
      expect(
        inbox.newTaskLink,
        'vikunja-io.vikunja.app://widget/new-task?account='
        '$accountId&project=1',
      );
    });

    test('read only: no Done, and new tasks go elsewhere', () async {
      final shared = await one(const ProjectTasksKind(2));

      expect(titles(shared), ['Tomorrow, read only']);
      expect(shared.rows.single.canDone, isFalse);
      expect(
        shared.newTaskLink,
        'vikunja-io.vikunja.app://widget/new-task?account=$accountId',
      );
    });

    test('an archived project shows its tasks without Done', () async {
      final old = await one(const ProjectTasksKind(3));

      expect(titles(old), ['Archived']);
      expect(old.rows.single.canDone, isFalse);
    });

    test('one that is gone says so', () async {
      final gone = await one(const ProjectTasksKind(99));

      expect(gone.state, WidgetSnapshotState.gone);
      expect(gone.rows, isEmpty);
      expect(gone.message?.title, 'This project no longer exists');
      expect(gone.message?.body, 'Choose another list for this widget.');
      expect(
        gone.messageLink,
        'vikunja-io.vikunja.app://widget/open?account=$accountId',
      );
    });
  });

  test('a label lists its open tasks through the filter engine', () async {
    final label = await one(const LabelTasksKind(5));
    final gone = await one(const LabelTasksKind(6));

    expect(label.title, 'Garden');
    expect(titles(label), ['Weeding']);
    expect(gone.state, WidgetSnapshotState.gone);
    expect(gone.title, 'This label is gone');
  });

  test('a widget set up for a label created here follows it to its server '
      'id once its create is answered', () async {
    await db.labelOpsDao.queueCreate(const NewLabel(title: 'Shed'), now: now);
    await db.outboxDao.queueUpdate(
      5,
      const TaskChanges(labels: IdSetChange(added: {-1})),
      now: now,
    );
    expect(titles(await one(const LabelTasksKind(-1))), ['Weeding']);

    await db.labelOpsDao.completeCreate(
      (await db.labelOpsDao.createOf(-1))!.id,
      const Label(id: 50, title: 'Shed'),
      at: now,
    );

    final followed = await one(const LabelTasksKind(-1));
    expect(followed.title, 'Shed');
    expect(titles(followed), ['Weeding']);
  });

  test('Favorites lists the open favourite tasks', () async {
    final favorites = await one(const FavoritesKind());

    expect(favorites.title, 'Favorites');
    expect(titles(favorites), ['Saturday']);
  });

  group('Saved filter', () {
    setUp(
      () => db.syncStateDao.write({
        SyncStateKeys.savedFilters: encodeSavedFilters([
          const SavedFilterRef(
            projectId: -2,
            title: 'Important',
            definition: SavedFilterDefinition(
              filter: ViewFilter(filter: 'priority >= 3 && done = false'),
            ),
          ),
        ]),
      }),
    );

    test('is evaluated here', () async {
      final filter = await one(const SavedFilterKind(1));

      expect(filter.title, 'Important');
      expect(titles(filter), ['This afternoon']);
      expect(
        filter.link,
        'vikunja-io.vikunja.app://widget/list?account=$accountId'
        '&kind=savedFilter&id=1',
      );
    });

    test('is gone when the sync no longer lists it, and for a '
        'guest', () async {
      final missing = await one(const SavedFilterKind(7));
      final guest = await one(
        const SavedFilterKind(1),
        account: const WidgetAccount(
          id: accountId,
          title: 'Helper',
          host: 'vikunja.example.com',
          isGuest: true,
          sessionEnded: false,
          supportsV2: true,
        ),
      );

      expect(missing.state, WidgetSnapshotState.gone);
      expect(guest.state, WidgetSnapshotState.gone);
      expect(guest.title, 'This saved filter is gone');
    });
  });

  test('rows stop at 30, the rest counted', () async {
    await db.tasksDao.upsertAll([
      for (var id = 100; id < 140; id++) sampleTask(id: id, title: 'Task $id'),
    ], syncRunId: 'run');

    final inbox = await one(const ProjectTasksKind(1));

    expect(inbox.rows, hasLength(WidgetSnapshot.maxRows));
    expect(inbox.total, 44);
    expect(inbox.more, 14);
    expect(inbox.moreLabel, '+14 more');
    expect(inbox.countLabel, '44 tasks');
  });

  group('without task titles', () {
    Future<Map<String, WidgetSnapshot>> hidden(
      Set<WidgetKind> kinds, {
      WidgetTexts? using,
    }) async => (await WidgetSnapshotBuilder(
      db: db,
      texts: using ?? texts,
      showTaskTitles: false,
      now: () => now,
    ).build(alice, kinds, withCatalog: false)).snapshots;

    test('a list keeps its title, count and links but no row, and says '
        'where to see them', () async {
      await db.tasksDao.upsertAll([
        for (var id = 100; id < 140; id++)
          sampleTask(id: id, title: 'Task $id'),
      ], syncRunId: 'run');

      final snapshots = await hidden({
        const TodayKind(),
        const ProjectTasksKind(1),
      });
      final today = snapshots['$accountId.today']!;
      final inbox = snapshots['$accountId.project_1']!;

      expect(today.title, 'Today');
      expect(today.rows, isEmpty);
      expect(today.total, 2);
      expect(today.countLabel, '2 tasks');
      // The count as the title, the hint in the smaller body that both
      // renderers wrap over more lines.
      expect(
        today.empty,
        const WidgetText('2 tasks', body: 'Open Vikunja to see them'),
      );
      expect(today.changesAt, isEmpty);
      expect(today.link, isNotNull);
      expect(today.newTaskLink, isNotNull);
      expect(inbox.title, 'Inbox');
      expect(inbox.rows, isEmpty);
      expect(inbox.total, 44);
      expect(inbox.moreLabel, isNull);
      expect(
        inbox.empty,
        const WidgetText('44 tasks', body: 'Open Vikunja to see them'),
      );
      for (final snapshot in snapshots.values) {
        expect(snapshot.encode(), isNot(contains('This afternoon')));
        expect(snapshot.encode(), isNot(contains('Task 1')));
      }
    });

    test('an empty list keeps its own empty text', () async {
      await db.tasksDao.upsertAll([
        sampleTask(
          id: 1,
          title: 'Yesterday',
          due: DateTime(2026, 10, 25, 9),
          done: true,
        ),
      ], syncRunId: 'run');

      final overdue = (await hidden({const OverdueKind()})).values.single;

      expect(overdue.total, 0);
      expect(overdue.empty, const WidgetText('Nothing overdue'));
    });

    test('one task is "it"', () async {
      final overdue = (await hidden({const OverdueKind()})).values.single;

      expect(overdue.total, 1);
      expect(
        overdue.empty,
        const WidgetText('1 task', body: 'Open Vikunja to see it'),
      );
    });

    test('one task, in German', () async {
      final german = await WidgetTexts.load(
        lookupAppLocalizations(const Locale('de')),
        alwaysUse24HourFormat: true,
      );

      final overdue = (await hidden({
        const OverdueKind(),
      }, using: german)).values.single;

      expect(overdue.total, 1);
      expect(
        overdue.empty,
        const WidgetText('1 Aufgabe', body: 'Öffne Vikunja, um sie zu sehen'),
      );
    });
  });

  test('an ended session keeps the rows and asks for a new '
      'sign-in', () async {
    final user = await one(
      const TodayKind(),
      account: const WidgetAccount(
        id: accountId,
        title: 'Alice',
        host: 'vikunja.example.com',
        isGuest: false,
        sessionEnded: true,
        supportsV2: true,
        showsAccount: true,
      ),
    );
    final guest = await one(
      const TodayKind(),
      account: const WidgetAccount(
        id: accountId,
        title: 'Helper',
        host: 'vikunja.example.com',
        isGuest: true,
        sessionEnded: true,
        supportsV2: false,
      ),
    );

    expect(user.state, WidgetSnapshotState.needsReauth);
    expect(user.rows, hasLength(2));
    expect(user.message?.title, 'Signed out by the server');
    expect(user.message?.action, 'Sign in again');
    expect(
      user.messageLink,
      'vikunja-io.vikunja.app://widget/account?account=$accountId',
    );
    expect(user.subtitle, 'Alice · vikunja.example.com');
    expect(guest.state, WidgetSnapshotState.guestEnded);
    expect(guest.message?.title, 'Guest access ended');
    expect(guest.message?.action, 'Open the link again');
    expect(guest.subtitle, isNull);
  });

  test('an end on the device is not told as a sign-out by the server '
      '(decision log: Sessions)', () async {
    const user = WidgetAccount(
      id: accountId,
      title: 'Alice',
      host: 'vikunja.example.com',
      isGuest: false,
      sessionEnded: true,
      supportsV2: true,
    );
    const guest = WidgetAccount(
      id: accountId,
      title: 'Helper',
      host: 'vikunja.example.com',
      isGuest: true,
      sessionEnded: true,
      supportsV2: false,
    );

    final onDevice = await one(
      const TodayKind(),
      account: user.withEndedOnDevice(endedOnDevice: true),
    );
    final guestOnDevice = await one(
      const TodayKind(),
      account: guest.withEndedOnDevice(endedOnDevice: true),
    );

    expect(onDevice.message?.title, 'Signed out on this device');
    expect(onDevice.message?.action, 'Sign in again');
    expect(guestOnDevice.message?.title, 'Guest access ended on this device');
    expect(guestOnDevice.message?.action, 'Open the link again');
  });

  group('due labels', () {
    test('use the absolute format picked on the web', () async {
      await db.syncStateDao.write({
        SyncStateKeys.userSettings: encodeUserSettings(
          const UserSettings(dateDisplay: DateDisplay.yearMonthDayDashed),
        ),
      });

      final today = await one(const TodayKind());

      expect(today.rows.last.dueLabel, '2026-10-26 15:00');
      expect(today.rows.last.absoluteDueLabel, isNull);
      expect(today.rows.last.absoluteSemanticsLabel, isNull);
      expect(
        today.rows.last.overdueSemanticsLabel,
        'This afternoon\nInbox\nOverdue, due 2026-10-26 15:00\n'
        'Priority: High',
      );
      expect(today.rows.last.absoluteOverdueSemanticsLabel, isNull);
    });

    test('are spoken as overdue wherever the iOS extension shows a row as '
        'overdue, with the date past midnight', () async {
      await db.tasksDao.upsertAll([
        sampleTask(id: 8, title: 'In nine days', due: DateTime(2026, 11, 4, 9)),
      ], syncRunId: 'run');
      final rows = {
        for (final row in (await one(const UpcomingKind(14))).rows)
          row.title: row,
      };
      List<String?> labels(String title) {
        final row = rows[title]!;
        return [
          row.semanticsLabel,
          row.overdueSemanticsLabel,
          row.absoluteSemanticsLabel,
          row.absoluteOverdueSemanticsLabel,
        ];
      }

      expect(labels('Yesterday'), [
        'Yesterday\nInbox\nOverdue, due Yesterday, 09:00',
        null,
        'Yesterday\nInbox\nOverdue, due Oct 25, 09:00',
        null,
      ]);
      expect(labels('This afternoon'), [
        'This afternoon\nInbox\nDue Today, 15:00\nPriority: High',
        'This afternoon\nInbox\nOverdue, due Today, 15:00\nPriority: High',
        'This afternoon\nInbox\nOverdue, due Oct 26, 15:00\nPriority: High',
        null,
      ]);
      expect(labels('Tomorrow, read only'), [
        'Tomorrow, read only\nShared\nDue Tomorrow, 09:00',
        null,
        'Tomorrow, read only\nShared\nDue Oct 27, 09:00',
        'Tomorrow, read only\nShared\nOverdue, due Oct 27, 09:00',
      ]);
      expect(labels('In nine days'), [
        'In nine days\nInbox\nDue Nov 4',
        null,
        null,
        'In nine days\nInbox\nOverdue, due Nov 4',
      ]);
      expect(
        rows['Yesterday']!.toJson().keys,
        isNot(
          anyOf(contains('labelOverdue'), contains('labelAbsoluteOverdue')),
        ),
      );
    });

    test("follow the device's clock, and German", () async {
      final twelveHour = await one(
        const TodayKind(),
        using: await WidgetTexts.load(
          lookupAppLocalizations(const Locale('en')),
          alwaysUse24HourFormat: false,
        ),
      );
      final german = await one(
        const UpcomingKind(14),
        using: await WidgetTexts.load(
          lookupAppLocalizations(const Locale('de')),
          alwaysUse24HourFormat: true,
        ),
      );

      expect(twelveHour.rows.last.dueLabel, 'Today, 3:00 PM');
      expect(twelveHour.rows.last.absoluteDueLabel, 'Oct 26, 3:00 PM');
      expect(german.title, 'Nächste 14 Tage');
      expect(german.rows.first.dueLabel, 'Gestern, 09:00');
      expect(german.rows.first.absoluteDueLabel, '25. Okt., 09:00');
      expect(german.rows.last.dueLabel, 'Sa, 18:00');
      expect(german.rows.last.absoluteDueLabel, '31. Okt., 18:00');

      final germanTwelveHour = await one(
        const UpcomingKind(14),
        using: await WidgetTexts.load(
          lookupAppLocalizations(const Locale('de')),
          alwaysUse24HourFormat: false,
        ),
      );
      expect(germanTwelveHour.rows.first.dueLabel, 'Gestern, 9:00 AM');
      expect(germanTwelveHour.rows.last.absoluteDueLabel, '31. Okt., 6:00 PM');
    });

    test('name the date for after midnight where they name a day', () {
      final formatter = texts.formatter(const DisplaySettings());
      String? absolute(DateTime due, {DateTime? at}) =>
          texts.absoluteDueLabel(due, now: at ?? now, formatter: formatter);

      expect(absolute(DateTime(2026, 10, 25, 9)), 'Oct 25, 09:00');
      expect(absolute(DateTime(2026, 10, 26, 15)), 'Oct 26, 15:00');
      expect(absolute(DateTime(2026, 10, 27, 9)), 'Oct 27, 09:00');
      expect(absolute(DateTime(2026, 11, 1, 9)), 'Nov 1, 09:00');
      expect(
        absolute(DateTime(2027, 1, 2, 9), at: DateTime(2026, 12, 31, 10)),
        'Jan 2, 2027, 09:00',
      );
      expect(absolute(DateTime(2026, 10, 24, 9)), isNull, reason: 'a date');
      expect(absolute(DateTime(2026, 11, 2, 9)), isNull, reason: 'a date');
      expect(
        texts.absoluteDueLabel(
          DateTime(2026, 10, 26, 15),
          now: now,
          formatter: texts.formatter(
            const DisplaySettings(dateDisplay: DateDisplay.dayMonthYearDashed),
          ),
        ),
        isNull,
        reason: 'the format picked on the web',
      );
    });

    test('a week ahead and beyond show the date', () {
      final formatter = texts.formatter(const DisplaySettings());
      String label(DateTime due) =>
          texts.dueLabel(due, now: now, formatter: formatter);

      expect(label(DateTime(2026, 11, 2, 9)), 'Nov 2');
      expect(label(DateTime(2026, 10, 20, 9)), 'Oct 20');
      expect(label(DateTime(2027, 1, 4, 9)), 'Jan 4, 2027');
    });

    test("a week ahead and beyond show the date in the device's "
        'region', () async {
      final british = await WidgetTexts.load(
        appLocalizationsFor(const Locale('en', 'GB')),
        alwaysUse24HourFormat: false,
      );
      final formatter = british.formatter(const DisplaySettings());
      String label(DateTime due) =>
          british.dueLabel(due, now: now, formatter: formatter);

      expect(label(DateTime(2026, 11, 2, 9)), '2 Nov');
      expect(label(DateTime(2027, 1, 4, 9)), '4 Jan 2027');
    });

    test("in the device's region the clock still follows its 24-hour switch, "
        'unless the account sets one', () async {
      final afternoon = DateTime(2026, 10, 26, 15);
      Future<String> label({
        required bool device24Hour,
        TimeFormat? account,
      }) async {
        final british = await WidgetTexts.load(
          appLocalizationsFor(const Locale('en', 'GB')),
          alwaysUse24HourFormat: device24Hour,
        );
        return british.dueLabel(
          afternoon,
          now: now,
          formatter: british.formatter(DisplaySettings(timeFormat: account)),
        );
      }

      expect(await label(device24Hour: false), 'Today, 3:00 PM');
      expect(await label(device24Hour: true), 'Today, 15:00');
      expect(
        await label(device24Hour: false, account: TimeFormat.twentyFourHour),
        'Today, 15:00',
      );
      expect(
        await label(device24Hour: true, account: TimeFormat.twelveHour),
        'Today, 3:00 PM',
      );
    });

    test('count calendar days across the end of daylight saving', () {
      final saturdayNoon = DateTime(2026, 10, 24, 12);
      final mondayNoon = DateTime(2026, 10, 26, 12);

      expect(calendarDaysBetween(saturdayNoon, mondayNoon), 2);
      expect(
        calendarDaysBetween(DateTime(2026, 10, 25, 23, 30), mondayNoon),
        1,
      );
      expect(
        nextLocalMidnight(DateTime(2026, 10, 24, 23)),
        DateTime(2026, 10, 25),
      );
      expect(
        nextLocalMidnight(DateTime(2026, 10, 25, 1)),
        DateTime(2026, 10, 26),
      );
    });
  });

  group('Quick add', () {
    test('links to the new-task sheet where a project takes tasks', () async {
      final quickAdd = await one(const QuickAddKind());

      expect(quickAdd.title, 'New task');
      expect(quickAdd.rows, isEmpty);
      expect(
        quickAdd.newTaskLink,
        'vikunja-io.vikunja.app://widget/new-task?account=$accountId',
      );
      expect(quickAdd.empty, isNull);
    });

    test('has no link without a writable project', () async {
      await db.projectsDao.upsertAll([
        sampleProject(
          id: 1,
          title: 'Inbox',
        ).copyWith(maxPermission: Permission.read),
      ]);

      final quickAdd = await one(const QuickAddKind());

      expect(quickAdd.newTaskLink, isNull);
      expect(
        quickAdd.empty?.title,
        "There's no project to add tasks to yet. "
        'Create one on the Projects tab first.',
      );
    });

    test('has no link when the only writable project was unarchived below '
        'an archived one (before 2.6)', () async {
      await db.projectsDao.upsertAll([
        sampleProject(
          id: 1,
          title: 'Inbox',
          parent: 3,
        ).copyWith(maxPermission: Permission.admin),
      ]);

      final quickAdd = await one(const QuickAddKind());

      expect(quickAdd.newTaskLink, isNull);
    });

    test('tells a read-only guest why, not to create a project', () async {
      await db.projectsDao.upsertAll([
        sampleProject(
          id: 1,
          title: 'Inbox',
        ).copyWith(maxPermission: Permission.read),
      ]);

      final quickAdd = await one(
        const QuickAddKind(),
        account: const WidgetAccount(
          id: accountId,
          title: 'Helper',
          host: 'vikunja.example.com',
          isGuest: true,
          sessionEnded: false,
          supportsV2: true,
        ),
      );

      expect(quickAdd.newTaskLink, isNull);
      expect(
        quickAdd.empty?.title,
        "You can't add tasks through this shared link: it is read-only, or "
        'the project is archived.',
      );
    });
  });

  group('catalog', () {
    Future<WidgetCatalog> catalogOf(WidgetAccount account) async =>
        (await WidgetSnapshotBuilder(
          db: db,
          texts: texts,
          now: () => now,
        ).build(account, const {})).catalog!;

    setUp(
      () => db.syncStateDao.write({
        SyncStateKeys.savedFilters: encodeSavedFilters([
          const SavedFilterRef(projectId: -3, title: 'My Open Tasks'),
        ]),
      }),
    );

    test('offers the smart lists, the projects without the archived, the '
        'labels and the saved filters', () async {
      final catalog = await catalogOf(alice);

      expect(catalog.account.name, 'Alice');
      expect(catalog.account.host, 'vikunja.example.com');
      expect(catalog.account.supportsV2, isTrue);
      expect(catalog.canAddTasks, isTrue);
      expect(
        [for (final list in catalog.lists) (list.section, list.title)],
        [
          (WidgetCatalogSection.smart, 'Today'),
          (WidgetCatalogSection.smart, 'Next 3 days'),
          (WidgetCatalogSection.smart, 'Next 7 days'),
          (WidgetCatalogSection.smart, 'Next 14 days'),
          (WidgetCatalogSection.smart, 'Overdue'),
          (WidgetCatalogSection.smart, 'Favorites'),
          (WidgetCatalogSection.project, 'Inbox'),
          (WidgetCatalogSection.project, 'Shared'),
          (WidgetCatalogSection.label, 'Garden'),
          (WidgetCatalogSection.savedFilter, 'My Open Tasks'),
        ],
      );
      final inbox = catalog.lists[6];
      expect(inbox.key, '$accountId.project_1');
      expect(inbox.writable, isTrue);
      expect(inbox.color, '1973ff');
      expect(catalog.lists[7].writable, isFalse);
      expect(catalog.lists[8].color, '4caf50');
      expect(catalog.lists.last.key, '$accountId.filter_2');
    });

    test('a project unarchived below an archived one (before 2.6) takes no '
        'tasks', () async {
      await db.projectsDao.upsertAll([
        sampleProject(
          id: 1,
          title: 'Inbox',
          parent: 3,
        ).copyWith(maxPermission: Permission.admin),
      ]);

      final catalog = await catalogOf(alice);

      expect(catalog.canAddTasks, isFalse);
      expect(
        catalog.lists
            .singleWhere((list) => list.key == '$accountId.project_1')
            .writable,
        isFalse,
      );
    });

    test('names the projects above a nested one', () async {
      await db.projectsDao.upsertAll([
        sampleProject(id: 4, title: 'Inbox', parent: 2),
        sampleProject(id: 5, title: 'Calls', parent: 4),
      ]);

      final catalog = await catalogOf(alice);

      expect(
        [
          for (final list in catalog.lists)
            if (list.section == WidgetCatalogSection.project)
              (list.title, list.parent),
        ],
        [
          ('Inbox', null),
          ('Shared', null),
          ('Inbox', 'Shared'),
          ('Calls', 'Shared › Inbox'),
        ],
      );
    });

    test('offers a guest no saved filter', () async {
      final catalog = await catalogOf(
        const WidgetAccount(
          id: accountId,
          title: 'Helper',
          host: 'vikunja.example.com',
          isGuest: true,
          sessionEnded: false,
          supportsV2: false,
        ),
      );

      expect(catalog.account.isGuest, isTrue);
      expect(
        catalog.lists.where(
          (list) => list.section == WidgetCatalogSection.savedFilter,
        ),
        isEmpty,
      );
    });
  });
}
