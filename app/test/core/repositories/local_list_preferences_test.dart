import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/local/local_list_preferences.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late LocalListPreferences preferences;

  setUp(() {
    db = testDatabase();
    preferences = LocalListPreferences(db);
  });

  group('views', () {
    test('start at the manual order without done tasks', () async {
      expect(
        await preferences.watchView('view:70').first,
        const ViewPreferences(),
      );
    });

    test('are saved per list and streamed on change only', () async {
      final seen = <ViewPreferences>[];
      final subscription = preferences.watchView('view:70').listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await preferences.saveView(
        'view:70',
        const ViewPreferences(sort: TaskListSort.dueDateDesc, showDone: true),
      );
      await preferences.saveView('view:71', const ViewPreferences());
      await preferences.saveView(
        'view:70',
        const ViewPreferences(sort: TaskListSort.dueDateDesc, showDone: true),
      );
      await pumpEventQueue();

      expect(seen, const [
        ViewPreferences(),
        ViewPreferences(sort: TaskListSort.dueDateDesc, showDone: true),
      ]);
      expect(
        await preferences.watchView(listKeyFor(projectId: 7, viewId: 0)).first,
        const ViewPreferences(),
      );
    });

    test('every sort survives the round trip', () async {
      for (final sort in TaskListSort.values) {
        await preferences.saveView('view:70', ViewPreferences(sort: sort));
        expect(
          (await preferences.watchView('view:70').first).sort,
          sort,
          reason: sort.name,
        );
      }
    });

    test('an unreadable value is the default, field by field', () async {
      for (final (stored, expected) in [
        ('not json', const ViewPreferences()),
        ('[1]', const ViewPreferences()),
        (
          '{"sort": "loud", "show_done": true}',
          const ViewPreferences(showDone: true),
        ),
        (
          '{"sort": "title:desc", "show_done": "yes"}',
          const ViewPreferences(sort: TaskListSort.titleDesc),
        ),
      ]) {
        await db.listPreferencesDao.write('list:view:70', stored);
        expect(
          await preferences.watchView('view:70').first,
          expected,
          reason: stored,
        );
      }
    });
  });

  group('last view', () {
    test('is remembered per project', () async {
      expect(await preferences.lastViewOf(7), isNull);

      await preferences.rememberView(7, 70);
      await preferences.rememberView(8, 0);

      expect(await preferences.lastViewOf(7), 70);
      expect(await preferences.lastViewOf(8), 0);

      await preferences.rememberView(7, 72);

      expect(await preferences.lastViewOf(7), 72);
    });

    test('an unreadable value is none', () async {
      for (final stored in ['x', '{"view_id": "70"}', '{"view_id": -3}']) {
        await db.listPreferencesDao.write('last_view:7', stored);
        expect(await preferences.lastViewOf(7), isNull, reason: stored);
      }
    });
  });

  group('Upcoming', () {
    test('starts at the next 7 days with the overdue tasks', () async {
      final upcoming = await preferences.watchUpcoming().first;

      expect(upcoming, const UpcomingPreferences());
      expect(upcoming.preset, DateRangePreset.next7Days);
      expect(upcoming.showOverdue, isTrue);
      expect(upcoming.showWithoutDueDate, isFalse);
    });

    test('a preset and the toggles survive the round trip', () async {
      const saved = UpcomingPreferences(
        preset: DateRangePreset.thisMonth,
        showOverdue: false,
        showWithoutDueDate: true,
      );

      await preferences.saveUpcoming(saved);

      expect(await preferences.watchUpcoming().first, saved);
    });

    test('a custom range keeps its local dates', () async {
      final saved = UpcomingPreferences(
        customFrom: DateTime(2026, 10),
        customTo: DateTime(2026, 12, 31),
      ).copyWith(clearPreset: true);

      await preferences.saveUpcoming(saved);
      final read = await preferences.watchUpcoming().first;

      expect(read, saved);
      expect(read.preset, isNull);
      expect(read.customFrom, DateTime(2026, 10));
    });

    test('a custom range missing an end is the default preset', () async {
      await db.listPreferencesDao.write(
        'upcoming',
        '{"preset": null, "custom_from": "2026-10-01"}',
      );

      final read = await preferences.watchUpcoming().first;

      expect(read.preset, DateRangePreset.next7Days);
      expect(read.customFrom, DateTime(2026, 10));
      expect(read.customTo, isNull);
    });

    test('an unreadable value is the default, field by field', () async {
      for (final (stored, expected) in [
        ('', const UpcomingPreferences()),
        ('{"preset": "someday"}', const UpcomingPreferences()),
        (
          '{"preset": null, "custom_from": "2026-02-31", '
              '"custom_to": "2026-03-01"}',
          UpcomingPreferences(customTo: DateTime(2026, 3)),
        ),
        (
          '{"preset": "today", "show_overdue": 0, '
              '"show_without_due_date": true}',
          const UpcomingPreferences(
            preset: DateRangePreset.today,
            showWithoutDueDate: true,
          ),
        ),
      ]) {
        await db.listPreferencesDao.write('upcoming', stored);
        expect(
          await preferences.watchUpcoming().first,
          expected,
          reason: stored,
        );
      }
    });

    test('streams every change', () async {
      final seen = <UpcomingPreferences>[];
      final subscription = preferences.watchUpcoming().listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await preferences.saveUpcoming(
        const UpcomingPreferences(showWithoutDueDate: true),
      );
      await pumpEventQueue();

      expect(seen, const [
        UpcomingPreferences(),
        UpcomingPreferences(showWithoutDueDate: true),
      ]);
    });
  });

  group('project tree', () {
    test('starts without archived projects, every project open', () async {
      final tree = await preferences.watchProjectTree().first;

      expect(tree, const ProjectTreePreferences());
      expect(tree.showArchived, isFalse);
      expect(tree.collapsed, isEmpty);
    });

    test('the toggle and the collapsed projects survive the round '
        'trip', () async {
      const saved = ProjectTreePreferences(
        showArchived: true,
        collapsed: {12, 3, 40},
      );

      await preferences.saveProjectTree(saved);

      expect(await preferences.watchProjectTree().first, saved);
      expect(
        await db.listPreferencesDao.read('projects'),
        '{"show_archived":true,"collapsed":[3,12,40]}',
      );
    });

    test('streams on change only', () async {
      final seen = <ProjectTreePreferences>[];
      final subscription = preferences.watchProjectTree().listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await preferences.saveProjectTree(
        const ProjectTreePreferences(collapsed: {7}),
      );
      await preferences.saveProjectTree(
        const ProjectTreePreferences(collapsed: {7}),
      );
      await preferences.saveView('view:70', const ViewPreferences());
      await preferences.saveProjectTree(
        const ProjectTreePreferences(showArchived: true, collapsed: {7}),
      );
      await pumpEventQueue();

      expect(seen, const [
        ProjectTreePreferences(),
        ProjectTreePreferences(collapsed: {7}),
        ProjectTreePreferences(showArchived: true, collapsed: {7}),
      ]);
    });

    test('an unreadable value is the default, field by field', () async {
      for (final (stored, expected) in [
        ('', const ProjectTreePreferences()),
        ('[true]', const ProjectTreePreferences()),
        (
          '{"show_archived": "yes", "collapsed": "7"}',
          const ProjectTreePreferences(),
        ),
        (
          '{"show_archived": true, "collapsed": {"7": true}}',
          const ProjectTreePreferences(showArchived: true),
        ),
        (
          '{"collapsed": [7, "8", 9.5, null, 10]}',
          const ProjectTreePreferences(collapsed: {7, 10}),
        ),
      ]) {
        await db.listPreferencesDao.write('projects', stored);
        expect(
          await preferences.watchProjectTree().first,
          expected,
          reason: stored,
        );
      }
    });
  });
}
