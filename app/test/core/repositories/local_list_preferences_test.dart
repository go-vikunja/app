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

  group('a table view', () {
    test('starts with the highest number first', () async {
      final read = await preferences.watchView('view:72').first;

      expect(read.tableSort, TableSort.defaultSort);
      expect(read.tableSort.wireName, 'index:desc');
    });

    test("every sort survives the round trip, in the web's URL "
        'form', () async {
      for (final field in TableSortField.values) {
        for (final descending in [false, true]) {
          final sort = TableSort(field, descending: descending);
          if (field == TableSortField.taskIndex && !descending) continue;
          await preferences.saveView(
            'view:72',
            ViewPreferences(tableSort: sort),
          );
          expect(
            (await preferences.watchView('view:72').first).tableSort,
            sort,
            reason: sort.wireName,
          );
          expect(
            await db.listPreferencesDao.read('list:view:72'),
            contains('"table_sort":"${sort.wireName}"'),
          );
        }
      }
    });

    test('an unknown sort falls back to the default, not to manual, and '
        'leaves the other fields; so does the number lowest first, no longer '
        'offered', () async {
      for (final stored in [
        '{"table_sort": "index:asc", "show_done": true}',
        '{"table_sort": "position:asc", "show_done": true}',
        '{"table_sort": "index", "show_done": true}',
        '{"table_sort": "due_date:up", "show_done": true}',
        '{"table_sort": 3, "show_done": true}',
      ]) {
        await db.listPreferencesDao.write('list:view:72', stored);
        expect(
          await preferences.watchView('view:72').first,
          const ViewPreferences(showDone: true),
          reason: stored,
        );
      }
    });
  });

  group('a timeline', () {
    const range = GanttRange(
      from: CalendarDate(2026, 11, 1),
      to: CalendarDate(2026, 11, 30),
    );

    test('starts at the default range without dateless tasks, 36 wide, and '
        'the default follows today', () {
      const timeline = TimelinePreferences();

      expect(timeline.customRange, isNull);
      expect(timeline.withoutDates, isFalse);
      expect(timeline.dayWidth, 36);
      expect(
        timeline.range(DateTime(2026, 10, 26, 23, 59)),
        const GanttRange(
          from: CalendarDate(2026, 10, 11),
          to: CalendarDate(2026, 12, 20),
        ),
      );
      expect(
        timeline.range(DateTime(2026, 10, 27, 0, 1)).from,
        const CalendarDate(2026, 10, 12),
      );
    });

    test('a custom range, the toggle and the zoom survive the round trip, '
        'and Reset goes back to the default', () async {
      const saved = ViewPreferences(
        timeline: TimelinePreferences(
          customRange: range,
          withoutDates: true,
          dayWidth: 52,
        ),
      );

      await preferences.saveView('view:73', saved);

      expect(await preferences.watchView('view:73').first, saved);
      expect(
        await db.listPreferencesDao.read('list:view:73'),
        contains(
          '"timeline":{"range":{"from":"2026-11-01","to":"2026-11-30"},'
          '"without_dates":true,"day_width":52.0}',
        ),
      );
      expect(saved.timeline.range(DateTime(2026, 10, 26)), range);

      await preferences.saveView(
        'view:73',
        saved.copyWith(timeline: saved.timeline.copyWith(defaultRange: true)),
      );

      final reset = (await preferences.watchView('view:73').first).timeline;
      expect(reset.customRange, isNull);
      expect(reset.withoutDates, isTrue);
      expect(
        await db.listPreferencesDao.read('list:view:73'),
        contains('"range":"default"'),
      );
    });

    test('an unreadable value is the default, field by field', () async {
      for (final (stored, expected) in [
        ('{"timeline": "wide"}', const TimelinePreferences()),
        (
          '{"timeline": {"range": {"from": "2026-11-30", "to": "2026-11-01"}, '
              '"without_dates": true}}',
          const TimelinePreferences(withoutDates: true),
        ),
        (
          '{"timeline": {"range": {"from": "2026-11-01"}, "day_width": 50}}',
          const TimelinePreferences(dayWidth: 50),
        ),
        (
          '{"timeline": {"range": "custom", "without_dates": "yes", '
              '"day_width": "36"}}',
          const TimelinePreferences(),
        ),
        (
          '{"timeline": {"day_width": 5}}',
          const TimelinePreferences(dayWidth: 20),
        ),
        (
          '{"timeline": {"day_width": 500}}',
          const TimelinePreferences(dayWidth: 72),
        ),
        (
          '{"timeline": {"range": {"from": "2026-11-01", "to": "2026-11-30"}}}',
          const TimelinePreferences(customRange: range),
        ),
      ]) {
        await db.listPreferencesDao.write('list:view:73', stored);
        expect(
          (await preferences.watchView('view:73').first).timeline,
          expected,
          reason: stored,
        );
      }
    });

    test('a list view written before keeps its sort and done '
        'preferences', () async {
      await db.listPreferencesDao.write(
        'list:view:70',
        '{"sort":"due_date:asc","show_done":true}',
      );

      expect(
        await preferences.watchView('view:70').first,
        const ViewPreferences(sort: TaskListSort.dueDateAsc, showDone: true),
      );
    });

    test("a deleted view's preferences go, every kind's", () async {
      await preferences.saveView(
        'view:72',
        const ViewPreferences(
          tableSort: TableSort(TableSortField.title, descending: false),
        ),
      );
      await preferences.saveView(
        'view:73',
        const ViewPreferences(
          timeline: TimelinePreferences(customRange: range),
        ),
      );
      await preferences.saveView('view:74', const ViewPreferences());
      await preferences.saveTableColumns({TableColumn.title});

      await preferences.forget(viewIds: {72, 73});

      expect(await db.listPreferencesDao.read('list:view:72'), isNull);
      expect(await db.listPreferencesDao.read('list:view:73'), isNull);
      expect(await db.listPreferencesDao.read('list:view:74'), isNotNull);
      expect(await preferences.watchTableColumns().first, {TableColumn.title});
    });
  });

  group('table columns', () {
    test("start at the web's defaults without its number", () async {
      expect(await preferences.watchTableColumns().first, {
        TableColumn.done,
        TableColumn.title,
        TableColumn.labels,
        TableColumn.assignees,
        TableColumn.dueDate,
      });
    });

    test("are saved for the account by the web's keys in its order and "
        'streamed on change only', () async {
      final seen = <Set<TableColumn>>[];
      final subscription = preferences.watchTableColumns().listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await preferences.saveTableColumns({
        TableColumn.createdBy,
        TableColumn.title,
        TableColumn.percentDone,
        TableColumn.commentCount,
      });
      await preferences.saveTableColumns({
        TableColumn.title,
        TableColumn.percentDone,
        TableColumn.createdBy,
        TableColumn.commentCount,
      });
      await pumpEventQueue();

      expect(seen, [
        TableColumn.defaults,
        {
          TableColumn.title,
          TableColumn.commentCount,
          TableColumn.percentDone,
          TableColumn.createdBy,
        },
      ]);
      expect(
        await db.listPreferencesDao.read('table_columns'),
        '["title","commentCount","percentDone","createdBy"]',
      );
    });

    test('every column survives the round trip', () async {
      await preferences.saveTableColumns(TableColumn.values.toSet());

      expect(
        await preferences.watchTableColumns().first,
        TableColumn.values.toSet(),
      );
    });

    test('none or an unreadable value is the defaults, unknown keys are '
        'left out', () async {
      for (final (stored, expected) in [
        ('[]', TableColumn.defaults),
        ('{"columns": ["title"]}', TableColumn.defaults),
        ('["mood", 3, null]', TableColumn.defaults),
        ('not json', TableColumn.defaults),
        (
          '["dueDate", "mood", "doneAt"]',
          {TableColumn.dueDate, TableColumn.doneAt},
        ),
        // The number column the app no longer shows.
        ('["index", "done", "title"]', {TableColumn.done, TableColumn.title}),
        ('["index"]', TableColumn.defaults),
      ]) {
        await db.listPreferencesDao.write('table_columns', stored);
        expect(
          await preferences.watchTableColumns().first,
          expected,
          reason: stored,
        );
      }
    });

    test('an empty choice saves the defaults', () async {
      await preferences.saveTableColumns(const {});

      expect(await preferences.watchTableColumns().first, TableColumn.defaults);
    });
  });

  test("a forgotten project's last view from an older version goes", () async {
    await db.listPreferencesDao.write('last_view:7', '{"view_id":70}');
    await db.listPreferencesDao.write('last_view:8', '{"view_id":80}');

    await preferences.forget(projectIds: {7});

    expect(await db.listPreferencesDao.read('last_view:7'), isNull);
    expect(await db.listPreferencesDao.read('last_view:8'), '{"view_id":80}');
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
    test('starts without archived projects, with the saved filters, every '
        'project open', () async {
      final tree = await preferences.watchProjectTree().first;

      expect(tree, const ProjectTreePreferences());
      expect(tree.showArchived, isFalse);
      expect(tree.showSavedFilters, isTrue);
      expect(tree.collapsed, isEmpty);
    });

    test('the toggles and the collapsed projects survive the round '
        'trip', () async {
      const saved = ProjectTreePreferences(
        showArchived: true,
        showSavedFilters: false,
        collapsed: {12, 3, 40},
      );

      await preferences.saveProjectTree(saved);

      expect(await preferences.watchProjectTree().first, saved);
      expect(
        await db.listPreferencesDao.read('projects'),
        '{"show_archived":true,"show_saved_filters":false,'
        '"collapsed":[3,12,40]}',
      );
    });

    test('a value stored before the saved filters toggle shows '
        'them', () async {
      await db.listPreferencesDao.write(
        'projects',
        '{"show_archived":true,"collapsed":[3]}',
      );

      expect(
        await preferences.watchProjectTree().first,
        const ProjectTreePreferences(showArchived: true, collapsed: {3}),
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
          '{"show_archived": "yes", "show_saved_filters": "no", '
              '"collapsed": "7"}',
          const ProjectTreePreferences(),
        ),
        (
          '{"show_saved_filters": false}',
          const ProjectTreePreferences(showSavedFilters: false),
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
