import 'dart:convert';
import 'dart:io';

import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:vikunja_logic/vikunja_logic.dart';

bool _zonesLoaded = false;

/// The full database: the server accepts links like `GMT` and `CET`.
void loadTimeZones() {
  if (_zonesLoaded) return;
  tz_data.initializeTimeZones();
  _zonesLoaded = true;
}

tz.Location zone(String name) => switch (name) {
  'UTC' => tz.UTC,
  // The server's own zone, GMT on the probed server.
  'Local' => tz.getLocation('GMT'),
  _ => tz.getLocation(name),
};

List<Map<String, Object?>> loadJsonl(String name) => [
  for (final line in File('test/fixtures/filter/$name').readAsLinesSync())
    if (line.trim().isNotEmpty) jsonDecode(line) as Map<String, Object?>,
];

DateTime utc(String iso) => DateTime.parse(iso).toUtc();

FilterExpression parsed(String filter) => switch (parseTaskFilter(filter)) {
  final FilterExpression expression => expression,
  final FilterError error => throw StateError('$filter: $error'),
};

/// The keys of [tasks] that match, in the order given.
List<String> matchingKeys(
  String filter,
  Map<String, FilterableTask> tasks,
  FilterContext context,
) {
  final bound = parsed(filter).bind(context);
  return [
    for (final MapEntry(:key, :value) in tasks.entries)
      if (bound.matches(value)) key,
  ];
}

// The step 24 probe fixture (scratchpad/step24/probe/fixture.py, ids of the
// probed run): user A owns everything, B is assigned to some tasks.

const userA = 'probefbaee647';
const userB = 'probefc46a1e9';
const urgent = 535;
const home = 536;
const work = 537;
const mainProject = 1664;
const childProject = 1665;
const grandProject = 1666;
const otherProject = 1667;
const archivedProject = 1668;
const archivedChildProject = 1669;

const Map<int, int> _kanbanViews = {
  mainProject: 9037,
  childProject: 9041,
  grandProject: 9045,
  otherProject: 9049,
  archivedProject: 9053,
  archivedChildProject: 9057,
};

final DateTime _created = utc('2026-10-20T08:01:05Z');

FilterableTask _probeTask(
  int id,
  int projectId,
  int index,
  String title, {
  String description = '',
  String? due,
  String? start,
  String? end,
  int priority = 0,
  double percentDone = 0,
  String hexColor = '',
  int repeatAfter = 0,
  bool done = false,
  String? doneAt,
  Set<int> labels = const {},
  Set<String> assignees = const {},
  List<String> reminders = const [],
}) => FilterableTask(
  id: id,
  projectId: projectId,
  index: index,
  title: title,
  description: description,
  dueDate: due == null ? null : utc(due),
  startDate: start == null ? null : utc(start),
  endDate: end == null ? null : utc(end),
  priority: priority,
  percentDone: percentDone,
  hexColor: hexColor,
  repeatAfterSeconds: repeatAfter,
  done: done,
  doneAt: doneAt == null ? null : utc(doneAt),
  created: _created,
  updated: doneAt == null ? _created : utc(doneAt),
  createdById: 542,
  createdByUsername: userA,
  labelIds: labels,
  assigneeUsernames: assignees,
  reminders: [for (final reminder in reminders) utc(reminder)],
  bucketIds: {_kanbanViews[projectId]!: 1},
);

/// Every task of the fixture by its key; `a1` and `ac1` are in the
/// archived project tree.
final Map<String, FilterableTask> probeTasks = {
  't1': _probeTask(
    8837,
    mainProject,
    1,
    'Alpha report',
    description: '<p>Quarterly numbers</p>',
    due: '2026-10-20T21:30:00Z',
  ),
  't2': _probeTask(
    8838,
    mainProject,
    2,
    'Beta review',
    due: '2026-10-20T22:30:00Z',
    priority: 1,
    labels: {urgent},
    hexColor: 'ff0000',
  ),
  't3': _probeTask(
    8839,
    mainProject,
    3,
    'gamma Plan',
    due: '2026-10-20T00:30:00Z',
    priority: 2,
    labels: {urgent, home},
    assignees: {userA},
    percentDone: 0.25,
    start: '2026-10-18T08:00:00Z',
    end: '2026-10-22T18:00:00Z',
  ),
  't4': _probeTask(
    8840,
    mainProject,
    4,
    'Delta',
    due: '2026-10-19T22:30:00Z',
    priority: 3,
    labels: {home},
    assignees: {userB},
  ),
  't5': _probeTask(
    8841,
    mainProject,
    5,
    'Epsilon done',
    due: '2026-10-01T12:00:00Z',
    priority: 4,
    labels: {urgent, home, work},
    assignees: {userA, userB},
    done: true,
  ),
  't6': _probeTask(
    8842,
    mainProject,
    6,
    'Zeta 100% sure',
    priority: 5,
    percentDone: 0.5,
    start: '2026-10-21T00:00:00Z',
    end: '2026-10-25T00:00:00Z',
  ),
  't7': _probeTask(8843, mainProject, 7, 'Eta_under', percentDone: 1),
  't8': _probeTask(
    8844,
    mainProject,
    8,
    'Theta',
    due: '2026-11-15T12:00:00Z',
    repeatAfter: 86400,
    reminders: ['2026-10-25T08:00:00Z', '2026-10-20T22:30:00Z'],
  ),
  't9': _probeTask(
    8845,
    mainProject,
    9,
    'Iota',
    description: '<p>mentions ALPHA in the text</p>',
    done: true,
    doneAt: '2026-10-20T08:02:11.012Z',
  ),
  't10': _probeTask(8846, mainProject, 10, 'Kappa #12 literal'),
  't11': _probeTask(
    8847,
    mainProject,
    11,
    'Ärger mit Öl',
    description: '<p>straße</p>',
  ),
  't12': _probeTask(8848, mainProject, 12, 'Lambda 50% off'),
  'c1': _probeTask(
    8849,
    childProject,
    1,
    'Child alpha',
    due: '2026-10-20T21:30:00Z',
    labels: {urgent},
  ),
  'c2': _probeTask(8850, childProject, 2, 'Child done', done: true),
  'g1': _probeTask(
    8851,
    grandProject,
    1,
    'Grandchild task',
    assignees: {userA},
  ),
  'o1': _probeTask(8852, otherProject, 1, 'Other alpha', priority: 3),
  'o2': _probeTask(8853, otherProject, 2, 'Other', labels: {work}),
  'a1': _probeTask(
    8854,
    archivedProject,
    1,
    'Archived alpha',
    due: '2026-10-20T21:30:00Z',
    labels: {urgent},
  ),
  'ac1': _probeTask(8855, archivedChildProject, 1, 'Archived child alpha'),
};

/// What `GET /tasks` covers for user A: no archived project tree.
final Map<String, FilterableTask> probeAllTasks = {
  for (final MapEntry(:key, :value) in probeTasks.entries)
    if (key != 'a1' && key != 'ac1') key: value,
};

/// Sorted like the probe printed keys: by letter, then number.
List<String> sortedKeys(Iterable<String> keys) => [...keys]
  ..sort((a, b) {
    final letters = a[0].compareTo(b[0]);
    if (letters != 0) return letters;
    return _number(a).compareTo(_number(b));
  });

int _number(String key) =>
    int.tryParse(key.replaceAll(RegExp('[^0-9]'), '')) ?? 0;

// Upstream's model fixture, as far as language.md §14.1 needs it: the tasks
// user 1 sees (U1); legacy NULL priority everywhere but tasks 3 and 4, NULL
// done on task 39.

const fxUser1 = 'user1';
const fxUser6 = 'user6';

FilterableTask _fxTask(
  int id, {
  int projectId = 1,
  int? index,
  String? title,
  String description = '',
  String creator = fxUser1,
  bool? done = false,
  int? priority,
  double? percentDone,
  String hexColor = '',
  int repeatAfter = 0,
  String? due,
  String? start,
  String? end,
  Set<int> labels = const {},
  Set<String> assignees = const {},
  List<String> reminders = const [],
}) => FilterableTask(
  id: id,
  projectId: projectId,
  index: index ?? id,
  title: title ?? 'task #$id',
  description: description,
  done: done,
  priority: priority,
  percentDone: percentDone,
  hexColor: hexColor,
  repeatAfterSeconds: repeatAfter,
  dueDate: due == null ? null : utc(due),
  startDate: start == null ? null : utc(start),
  endDate: end == null ? null : utc(end),
  createdById: creator == fxUser1 ? 1 : 6,
  createdByUsername: creator,
  labelIds: labels,
  assigneeUsernames: assignees,
  reminders: [for (final reminder in reminders) utc(reminder)],
);

const _fxProjectOf = {
  15: 6,
  16: 7,
  17: 8,
  18: 9,
  19: 10,
  20: 11,
  21: 32,
  22: 33,
  23: 34,
  24: 15,
  25: 16,
  26: 17,
};

/// U1 by task id.
final Map<int, FilterableTask> fxTasks = {
  1: _fxTask(1, description: 'Lorem Ipsum', labels: {4}),
  2: _fxTask(
    2,
    title: 'task #2 done',
    done: true,
    labels: {4},
    reminders: ['2018-12-01T01:13:44Z', '2019-06-01T12:00:00Z'],
  ),
  3: _fxTask(3, title: 'task #3 high prio', priority: 100),
  4: _fxTask(4, title: 'task #4 low prio', priority: 1),
  5: _fxTask(5, title: 'task #5 higher due date', due: '2018-12-01T03:58:44Z'),
  6: _fxTask(
    6,
    title: 'task #6 lower due date',
    description: 'This has something unique',
    due: '2018-11-30T22:25:24Z',
  ),
  7: _fxTask(
    7,
    title: 'task #7 with start date',
    start: '2018-12-12T07:33:20Z',
  ),
  8: _fxTask(8, title: 'task #8 with end date', end: '2018-12-13T11:20:00Z'),
  9: _fxTask(
    9,
    title: 'task #9 with start and end date',
    start: '2018-12-12T07:33:20Z',
    end: '2018-12-13T11:20:00Z',
  ),
  for (final id in [10, 11, 12]) id: _fxTask(id, title: 'task #$id basic'),
  for (final MapEntry(key: id, value: project) in _fxProjectOf.entries)
    id: _fxTask(
      id,
      projectId: project,
      index: 1,
      creator: fxUser6,
      labels: id == 25 ? const {10} : const {},
    ),
  27: _fxTask(
    27,
    index: 18,
    title: 'task #27 with reminders and start_date',
    start: '2018-11-30T22:25:24Z',
    reminders: ['2018-12-01T01:12:04Z', '2018-12-01T01:13:44Z'],
  ),
  28: _fxTask(
    28,
    index: 13,
    title: 'task #28 with repeat after, start_date, end_date and due_date',
    due: '2018-12-02T22:25:24Z',
    start: '2018-11-30T22:25:24Z',
    end: '2018-12-13T11:20:00Z',
    repeatAfter: 3600,
  ),
  29: _fxTask(29, index: 14, title: 'task #29 with parent task (1)'),
  30: _fxTask(
    30,
    index: 15,
    title: 'task #30 with assignees',
    assignees: {fxUser1, 'user2'},
  ),
  31: _fxTask(31, index: 16, title: 'task #31 with color', hexColor: 'f0f0f0'),
  32: _fxTask(32, projectId: 3, index: 1),
  33: _fxTask(
    33,
    index: 17,
    title: 'task #33 with percent done',
    percentDone: 0.5,
  ),
  39: _fxTask(39, projectId: 25, index: 0, done: null),
  47: _fxTask(
    47,
    index: 32,
    title: 'task #47 with reminders outside window',
    reminders: ['2018-08-01T12:00:00Z', '2019-03-01T12:00:00Z'],
  ),
  48: _fxTask(
    48,
    index: 33,
    title: 'Landingpages update',
    description: 'Update all landingpages with new branding',
  ),
};

/// Project 1's tasks.
final Set<int> fxProject1 = {
  for (final MapEntry(:key, :value) in fxTasks.entries)
    if (value.projectId == 1) key,
};

/// Sorted ids of [tasks] that match.
List<int> matchingIds(
  FilterExpression expression,
  Map<int, FilterableTask> tasks,
  FilterContext context,
) {
  final bound = expression.bind(context);
  return [
    for (final MapEntry(:key, :value) in tasks.entries)
      if (bound.matches(value)) key,
  ]..sort();
}
