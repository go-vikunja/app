import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/settings/user_settings_json.dart';
import 'package:vikunja_mobile/core/sync/saved_filters.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
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

  group('Today', () {
    test('lists the overdue and the due today, like the Overview', () async {
      final today = await one(const TodayKind());

      expect(today.key, '$accountId.today');
      expect(today.state, WidgetSnapshotState.ok);
      expect(today.title, 'Today');
      expect(titles(today), ['Yesterday', 'This afternoon']);
      final [yesterday, afternoon] = today.rows;
      expect(yesterday.dueLabel, 'Yesterday, 09:00');
      expect(yesterday.tone, WidgetDueTone.overdue);
      expect(afternoon.dueLabel, 'Today, 15:00');
      expect(afternoon.tone, WidgetDueTone.today);
      expect(afternoon.priorityLabel, 'High');
      expect(afternoon.priorityLevel, 3);
      expect(afternoon.projectTitle, 'Inbox');
      expect(afternoon.projectColor, '1973ff');
      expect(afternoon.canDone, isTrue);
      expect(
        afternoon.semanticsLabel,
        'This afternoon\nInbox\nDue Today, 15:00\nPriority: High',
      );
      expect(afternoon.doneLabel, 'Mark “This afternoon” as done');
      expect(
        afternoon.link,
        'vikunja-dev.coderoftime.vikunja://widget/task/2?account=$accountId',
      );
      expect(today.total, 2);
      expect(today.moreLabel, isNull);
      expect(today.countLabel, '2 tasks');
      expect(today.changesAt, [DateTime(2026, 10, 26, 15).toUtc()]);
      expect(today.validUntil, DateTime(2026, 10, 27));
      expect(
        today.link,
        'vikunja-dev.coderoftime.vikunja://widget/list?account=$accountId'
        '&kind=today',
      );
      expect(
        today.newTaskLink,
        'vikunja-dev.coderoftime.vikunja://widget/new-task?account=$accountId',
      );
      expect(today.message, isNull);
      expect(today.empty?.title, 'All done');
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
    expect(three.rows[2].tone, WidgetDueTone.later);
    expect(titles(fourteen).last, 'Saturday');
    expect(fourteen.rows.last.dueLabel, 'Sat, 18:00');
  });

  test('Overdue lists only what is overdue, outside archived '
      'projects', () async {
    final overdue = await one(const OverdueKind());

    expect(overdue.title, 'Overdue');
    expect(titles(overdue), ['Yesterday']);
    expect(overdue.empty?.title, 'Nothing overdue');
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
        'vikunja-dev.coderoftime.vikunja://widget/new-task?account='
        '$accountId&project=1',
      );
    });

    test('read only: no Done, and new tasks go elsewhere', () async {
      final shared = await one(const ProjectTasksKind(2));

      expect(titles(shared), ['Tomorrow, read only']);
      expect(shared.rows.single.canDone, isFalse);
      expect(
        shared.newTaskLink,
        'vikunja-dev.coderoftime.vikunja://widget/new-task?account=$accountId',
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
        'vikunja-dev.coderoftime.vikunja://widget/open?account=$accountId',
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

  test('Favorites lists the open favourite tasks', () async {
    final favorites = await one(const FavoritesKind());

    expect(favorites.title, 'Favourites');
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
        'vikunja-dev.coderoftime.vikunja://widget/list?account=$accountId'
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
        const WidgetText('2 tasks', body: 'Open Rurana to see them'),
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
        const WidgetText('44 tasks', body: 'Open Rurana to see them'),
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
        const WidgetText('1 Aufgabe', body: 'Öffne Rurana, um sie zu sehen'),
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
      'vikunja-dev.coderoftime.vikunja://widget/account?account=$accountId',
    );
    expect(user.subtitle, 'Alice · vikunja.example.com');
    expect(guest.state, WidgetSnapshotState.guestEnded);
    expect(guest.message?.title, 'Guest access ended');
    expect(guest.message?.action, 'Open the link again');
    expect(guest.subtitle, isNull);
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
      expect(german.title, 'Nächste 14 Tage');
      expect(german.rows.first.dueLabel, 'Gestern, 09:00');
      expect(german.rows.last.dueLabel, 'Sa, 18:00');
    });

    test('a week ahead and beyond show the date', () {
      final formatter = texts.formatter(const DisplaySettings());
      String label(DateTime due) =>
          texts.dueLabel(due, now: now, formatter: formatter);

      expect(label(DateTime(2026, 11, 2, 9)), 'Nov 2');
      expect(label(DateTime(2026, 10, 20, 9)), 'Oct 20');
      expect(label(DateTime(2027, 1, 4, 9)), 'Jan 4, 2027');
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
        'vikunja-dev.coderoftime.vikunja://widget/new-task?account=$accountId',
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
          (WidgetCatalogSection.smart, 'Favourites'),
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
