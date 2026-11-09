import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/filters/search_index.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_search.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/repositories/task_search.dart';
import 'package:vikunja_mobile/core/sync/saved_filters.dart';

import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late LocalTaskSearch search;
  final monday = DateTime.utc(2026, 10, 19, 9);
  final friday = DateTime.utc(2026, 10, 23, 9);
  const urgent = Label(id: 1, title: 'Urgent', description: 'Do it now');
  const home = Label(id: 2, title: 'Home');

  Task task(
    int id,
    String title, {
    int projectId = 1,
    int? index,
    String description = '',
    bool done = false,
    DateTime? due,
    bool favorite = false,
    List<Label> labels = const [],
  }) => sampleTask(
    id: id,
    title: title,
    projectId: projectId,
    description: description,
    done: done,
    due: due,
    favorite: favorite,
    labels: labels,
  ).copyWith(index: index ?? id);

  setUp(() async {
    db = testDatabase();
    search = LocalTaskSearch(db);
    await db.projectsDao.upsertAll([
      sampleProject(id: 1, title: 'Filter main', identifier: 'FLT'),
      sampleProject(id: 2, title: 'Other alpha'),
      sampleProject(id: 3, title: 'Archived alpha', archived: true),
      sampleProject(id: 4, title: 'Child of archived', parent: 3),
    ]);
    await db.labelsDao.upsertAll([urgent, home]);
    await db.tasksDao.upsertAll([
      task(
        1,
        'Alpha report',
        description: '<p>Quarterly numbers</p>',
        due: friday,
        labels: [urgent],
      ),
      task(2, 'Beta review', due: monday),
      task(3, 'gamma Plan', index: 3),
      task(9, 'Iota', description: '<p>mentions ALPHA in the text</p>'),
      task(10, 'Kappa #12 literal'),
      task(11, 'Ärger mit Öl', description: '<p>Straße</p>'),
      task(12, 'Lambda done', done: true, due: monday),
      task(20, 'Other alpha task', projectId: 2, index: 12),
      task(30, 'Archived alpha task', projectId: 3),
      task(31, 'Favourite archived alpha', projectId: 3, favorite: true),
      task(40, 'Under archived alpha', projectId: 4),
    ], syncRunId: 'run');
    await storeSavedFilters(db, const [
      SavedFilterRef(projectId: -14, title: 'My Open Tasks'),
      SavedFilterRef(
        projectId: -3,
        title: 'Weekly',
        description: 'The urgent ones',
      ),
    ]);
  });

  Future<SearchResults> find(String query) => search.watch(query).first;

  List<int> ids(SearchResults results) => [
    for (final task in results.tasks) task.id,
  ];

  test('an empty or blank query finds nothing', () async {
    for (final query in ['', '   ']) {
      final results = await find(query);

      expect(results.isEmpty, isTrue);
      expect(results.query, query);
    }
  });

  test('a task matches by a substring of its title or of its description '
      'text, ignoring case; archived projects are left out but favourite '
      'tasks', () async {
    final results = await find('ALPHA');

    expect(ids(results), [1, 31, 20, 9]);
    expect(results.taskCount, 4);
    expect(await find('quarterly').then(ids), [1]);
    // The description is compared as text, not as its HTML.
    expect(await find('<p>').then(ids), isEmpty);
  });

  test('open tasks come before done ones, then the nearest due date, then '
      'the newest', () async {
    expect(await find('a').then(ids), [2, 1, 31, 20, 11, 10, 9, 3, 12]);
  });

  test('case folding goes beyond lower case', () async {
    expect(await find('ÄRGER').then(ids), [11]);
    expect(await find('ärger').then(ids), [11]);
    expect(await find('strasse').then(ids), [11]);
  });

  test('accents are ignored, in the query too', () async {
    await db.projectsDao.upsertAll([sampleProject(id: 5, title: 'Café')]);
    await db.labelsDao.upsertAll([const Label(id: 3, title: 'Café')]);
    await storeSavedFilters(db, const [
      SavedFilterRef(projectId: -5, title: 'Cafés'),
    ]);
    await db.tasksDao.upsertAll([
      task(60, 'Café au lait'),
      task(61, 'Order', description: '<p>Ein Café</p>'),
      task(62, 'cafe'),
      task(63, 'Café decomposed'),
    ], syncRunId: 'run');

    final results = await find('cafe');
    expect(ids(results), [63, 62, 61, 60]);
    expect([for (final p in results.projects) p.id], [5]);
    expect([for (final f in results.savedFilters) f.title], ['Cafés']);
    expect([for (final l in results.labels) l.id], [3]);
    expect(await find('CAFÉ').then(ids), [63, 62, 61, 60]);
    expect(await find('café decomposed').then(ids), [63]);
    expect(await find('café au').then(ids), [60]);
    expect(await find('arger').then(ids), [11]);
  });

  test('#12 finds index 12 in any project and the titles holding it; a '
      'bare number only titles', () async {
    expect(await find('#12').then(ids), [20, 10, 12]);
    expect(await find('xyz#3').then(ids), [3]);
    expect(await find('12').then(ids), [10]);
    expect(await find('#0').then(ids), isEmpty);
  });

  test('an identifier like FLT-3 finds that task, ignoring case', () async {
    expect(await find('FLT-3').then(ids), [3]);
    expect(await find('flt-1').then(ids), [1]);
    expect(await find('FLT-99').then(ids), isEmpty);
    expect(await find('FLT').then(ids), isEmpty);
  });

  test('projects, saved filters and labels match by title or description, '
      'by title; archived projects are left out', () async {
    final results = await find('alpha');

    expect([for (final p in results.projects) p.id], [2]);
    expect(await find('urgent').then((r) => r.labels), [urgent]);
    expect(await find('now').then((r) => r.labels), [urgent]);
    expect(
      await find('urgent')
          .then((r) => [for (final f in r.savedFilters) f.title]),
      ['Weekly'],
    );
    expect(
      await find('open').then((r) => [for (final f in r.savedFilters) f.title]),
      ['My Open Tasks'],
    );
  });

  test('saved filter and label descriptions are matched by their text, '
      'not their markup', () async {
    await storeSavedFilters(db, const [
      SavedFilterRef(
        projectId: -5,
        title: 'Rich',
        description: '<p>Open <strong>work</strong> this week</p>',
      ),
    ]);
    await db.labelsDao.upsertAll([
      const Label(id: 3, title: 'Styled', description: '<p><em>Calm</em></p>'),
    ]);

    expect(await find('strong').then((r) => r.savedFilters), isEmpty);
    expect(
      await find('open work')
          .then((r) => [for (final f in r.savedFilters) f.title]),
      ['Rich'],
    );
    expect(await find('em').then((r) => r.labels), isEmpty);
    expect(await find('calm').then((r) => [for (final l in r.labels) l.id]), [
      3,
    ]);
  });

  test('a rebuilt index folds only the tasks whose text changed', () {
    final first = SearchIndex.build(
      tasks: [
        task(1, 'Alpha', description: '<p>One</p>'),
        task(2, 'Beta', description: '<p>Two</p>'),
        task(3, 'Gamma'),
      ],
      projects: const [],
      archivedProjectIds: const {},
    );
    expect(first.foldedTasks, 3);

    final second = SearchIndex.build(
      tasks: [
        task(1, 'Alpha', description: '<p>One</p>', done: true),
        task(2, 'Beta', description: '<p>Changed</p>'),
        task(3, 'Gamma'),
        task(4, 'Delta'),
      ],
      projects: const [],
      archivedProjectIds: const {},
      previous: first,
    );

    expect(second.foldedTasks, 2);
    expect(second.search('two').tasks, isEmpty);
    expect([for (final t in second.search('changed').tasks) t.id], [2]);
    expect(second.search('alpha').tasks.single.done, isTrue);
  });

  test('the tasks shown are loaded whole', () async {
    final results = await find('report');

    expect(results.tasks.single.labels, [urgent]);
  });

  test('at most maxTasks tasks are shown; the count says how many '
      'match', () async {
    await db.tasksDao.upsertAll([
      for (var id = 100; id < 100 + SearchResults.maxTasks + 5; id++)
        task(id, 'Bulk $id'),
    ], syncRunId: 'run');

    final results = await find('bulk');

    expect(results.tasks, hasLength(SearchResults.maxTasks));
    expect(results.taskCount, SearchResults.maxTasks + 5);
    expect(results.tasks.first.id, 100 + SearchResults.maxTasks + 4);
  });

  test('a change of the tasks shows in the results at once', () async {
    final seen = <SearchResults>[];
    final subscription = search.watch('beta').listen(seen.add);
    addTearDown(subscription.cancel);
    await pumpEventQueue();
    expect(ids(seen.last), [2]);

    await db.tasksDao.upsertAll([
      task(50, 'Another beta', due: DateTime.utc(2026, 10)),
    ], syncRunId: 'run');
    await pumpEventQueue();

    expect(ids(seen.last), [50, 2]);
  });
}
