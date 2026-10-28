import 'dart:async';

import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';

import '../features/teams/organise_harness.dart';
import '../helpers/auth_fakes.dart';
import '../helpers/label_user_fakes.dart';
import '../helpers/pump_app.dart';
import '../helpers/sample_data.dart';
import '../helpers/sync_fakes.dart';
import 'sweep_harness.dart';

/// Every scenario's clock: the fakes', the app's and the data's.
final sweepNow = DateTime(2026, 10, 10, 12);

const workProjectId = 1;
const gardenProjectId = 2;
const urgentFilterId = -2;
const listViewId = 11;
const ganttViewId = 12;
const tableViewId = 13;
const kanbanViewId = 14;

final Label errands = sampleLabel(id: 1, title: 'Errands', hexColor: 'ffeb10');
final Label calls = sampleLabel(id: 2, title: 'Calls', hexColor: '3a86ff');

List<Label> sweepLabels() => [
  ownLabel(1, 'Errands', hexColor: 'ffeb10', html: '<p>Out and about</p>'),
  ownLabel(2, 'Calls', hexColor: '3a86ff'),
  othersLabel(20, 'Shared shopping'),
];

/// Two projects with every kind of view, a saved filter and seven tasks
/// that between them carry each row attribute.
SyncFakes sweepData({SyncStatus? status}) {
  final data = SyncFakes(now: sweepNow, status: status);
  data.projects.all = [
    sampleProject(
      id: workProjectId,
      title: 'Work',
      favorite: true,
      hexColor: '1973ff',
      identifier: 'WORK',
      views: defaultViews(
        workProjectId,
        firstViewId: listViewId,
        defaultBucketId: 21,
        doneBucketId: 23,
      ),
    ).copyWith(maxPermission: Permission.admin),
    sampleProject(id: gardenProjectId, title: 'Garden', parent: workProjectId),
  ];
  data.projects.savedFilters = const [
    SavedFilterRef(
      projectId: urgentFilterId,
      title: 'Urgent',
      isFavorite: true,
      definition: SavedFilterDefinition(
        filter: ViewFilter(filter: 'done = false && priority >= 3'),
      ),
    ),
  ];
  data.tasks.all = [
    sampleTask(
      id: 1,
      title: 'Call the plumber',
      due: sweepNow.subtract(const Duration(days: 2)),
      identifier: 'WORK-1',
      priority: TaskPriority.doNow,
      labels: [calls],
      favorite: true,
      assignees: const [kim],
      description: '<p>About the kitchen sink.</p>',
      commentCount: 2,
      isUnread: true,
    ),
    sampleTask(
      id: 2,
      title: 'Buy seeds',
      projectId: gardenProjectId,
      due: sweepNow.add(const Duration(hours: 3)),
      identifier: 'WORK-2',
      priority: TaskPriority.high,
      labels: [errands],
      reminders: const [
        TaskReminder(
          relativePeriod: Duration(hours: -1),
          relativeTo: ReminderRelativeTo.dueDate,
        ),
      ],
    ),
    sampleTask(
      id: 3,
      title: 'Write the report',
      due: sweepNow.add(const Duration(days: 1)),
      start: sweepNow.subtract(const Duration(days: 2)),
      end: sweepNow.add(const Duration(days: 4)),
      identifier: 'WORK-3',
      percentDone: 0.5,
      repeatAfter: const Duration(days: 7),
    ),
    sampleTask(
      id: 4,
      title: 'Plan the team day',
      due: sweepNow.add(const Duration(days: 6)),
      start: sweepNow.add(const Duration(days: 5)),
      end: sweepNow.add(const Duration(days: 8)),
      identifier: 'WORK-4',
      priority: TaskPriority.low,
      relatedTasks: {
        TaskRelationKind.blocking: [sampleTask(id: 3, title: '')],
      },
    ),
    sampleTask(id: 5, title: 'Water the roses', projectId: gardenProjectId),
    sampleTask(
      id: 6,
      title: 'Read the contract',
      due: sweepNow.add(const Duration(days: 20)),
      identifier: 'WORK-6',
      favorite: true,
    ),
    sampleTask(
      id: 7,
      title: 'Send the invoice',
      done: true,
      doneAt: sweepNow.subtract(const Duration(hours: 5)),
      identifier: 'WORK-7',
    ),
  ];
  data.tasks.setSavedFilterMatches(urgentFilterId, {1, 2});
  data.tasks.setBoard(
    data.projects.all.first.views.firstWhere((view) => view.id == kanbanViewId),
    buckets: const [
      Bucket(id: 21, viewId: kanbanViewId, title: 'To do', position: 1),
      Bucket(
        id: 22,
        viewId: kanbanViewId,
        title: 'Doing',
        count: 2,
        limit: 2,
        position: 2,
      ),
      Bucket(id: 23, viewId: kanbanViewId, title: 'Done', position: 3),
    ],
    snapshot: const {
      1: (bucketId: 21, position: 1),
      3: (bucketId: 21, position: 2),
      4: (bucketId: 22, position: 3),
      6: (bucketId: 22, position: 4),
      7: (bucketId: 23, position: 5),
    },
    loadedAt: sweepNow,
  );
  data.teams
    ..me = alice
    ..people = [alice, kim, ben];
  data.shared.users.everyone = [alice, kim, ben];
  return data;
}

List<Override> sweepRepositoryOverrides() => [
  labelRepositoryProvider.overrideWithValue(
    FakeLabelRepository(labels: sweepLabels()),
  ),
  userRepositoryProvider.overrideWithValue(
    FakeUserRepository(
      projectUsers: const {
        workProjectId: [alice, kim, ben],
      },
      known: const [alice, kim, ben],
      everyone: const [alice, kim, ben],
    ),
  ),
];

/// Signed in as alice on a 2.7 server whose data is [data].
Future<AuthFakes> pumpSweepApp(
  WidgetTester tester, {
  SyncFakes? data,
  AuthFakes? auth,
  List<Override> overrides = const [],
  bool settle = true,
}) => pumpSignedInApp(
  tester,
  sync: data ?? sweepData(),
  auth: auth,
  now: sweepNow,
  overrides: [...sweepRepositoryOverrides(), ...overrides],
  settle: settle,
);

void goTo(WidgetTester tester, String location) =>
    routerOf(tester).go(location);

void pushTo(WidgetTester tester, String location, {Object? extra}) =>
    unawaited(routerOf(tester).push<Object?>(location, extra: extra));
