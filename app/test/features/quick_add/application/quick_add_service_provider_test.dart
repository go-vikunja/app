import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/settings/user_settings_providers.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_plan.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_service_provider.dart';

import '../../../helpers/label_user_fakes.dart';
import '../../../helpers/sample_data.dart';
import '../../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 12, 10, 15);
  final garage = sampleProject(id: 3, title: 'Garage');
  final home = sampleProject(id: 4, title: 'Home');
  const wichtig = Label(id: 10, title: 'wichtig');
  const alice = User(id: 20, username: 'alice');
  const ben = User(id: 21, username: 'ben');
  late FakeProjectRepository projects;
  late FakeTaskRepository tasks;
  late FakeLabelRepository labels;
  late FakeUserRepository users;

  setUp(() {
    final engine = FakeSyncEngine(clock: () => now);
    projects = FakeProjectRepository(engine)..all = [garage, home];
    tasks = FakeTaskRepository(engine);
    labels = FakeLabelRepository(labels: const [wichtig]);
    users = FakeUserRepository(
      projectUsers: {
        3: const [ben],
      },
      known: const [alice],
    );
  });

  List<Override> repositories({
    required FakeProjectRepository? projects,
    required FakeTaskRepository? tasks,
    required FakeLabelRepository? labels,
    required FakeUserRepository? users,
  }) => [
    projectRepositoryProvider.overrideWithValue(projects),
    taskRepositoryProvider.overrideWithValue(tasks),
    labelRepositoryProvider.overrideWithValue(labels),
    userRepositoryProvider.overrideWithValue(users),
  ];

  ProviderContainer containerWith({
    bool signedIn = true,
    bool guest = false,
    UserSettings settings = const UserSettings(),
  }) {
    final container = ProviderContainer(
      overrides: [
        activeAccountIsGuestProvider.overrideWithValue(guest),
        ...repositories(
          projects: signedIn ? projects : null,
          tasks: signedIn ? tasks : null,
          labels: signedIn ? labels : null,
          users: signedIn ? users : null,
        ),
        userSettingsProvider.overrideWith((ref) => Stream.value(settings)),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// The service once every snapshot has arrived.
  Future<QuickAddService> serviceOf(ProviderContainer container) async {
    final subscription = container.listen(quickAddServiceProvider, (_, _) {});
    addTearDown(subscription.close);
    await pumpEventQueue();
    return subscription.read()!;
  }

  test('null while nobody is signed in', () {
    final container = containerWith(signedIn: false);

    expect(container.read(quickAddServiceProvider), isNull);
  });

  test("plans with the account's projects, labels, people and "
      'settings', () async {
    final container = containerWith(
      settings: const UserSettings(
        defaultProjectId: 4,
        quickAddDefaultReminders: [Duration(minutes: -30)],
      ),
    );

    final plan = (await serviceOf(container))
        .plan('Reifen wechseln *wichtig @alice every week');

    expect(plan.title, 'Reifen wechseln');
    expect(plan.project, home);
    expect(plan.labels, [wichtig]);
    expect(plan.assignees, [alice]);
    expect(plan.dueDate, DateTime(2026, 10, 12, 12).toUtc());
    expect(plan.reminders.single.relativePeriod, const Duration(minutes: -30));
  });

  test("todoist mode from the user's settings", () async {
    final container = containerWith(
      settings: const UserSettings(
        quickAddMagicMode: QuickAddMagicMode.todoist,
      ),
    );

    final plan = (await serviceOf(container)).plan('a @wichtig #garage');

    expect(plan.labels, [wichtig]);
    expect(plan.project, garage);
  });

  test('a new label, project or person makes a new service that knows '
      'it', () async {
    final container = containerWith();
    final before = await serviceOf(container);
    expect(before.plan('a *errand').newLabels, ['errand']);

    await labels.create(const NewLabel(title: 'errand'));
    projects.all = [...projects.all, sampleProject(id: 5, title: 'Errands')];
    await users.searchAssignees(3, 'ben');
    await pumpEventQueue();
    final after = container.read(quickAddServiceProvider)!;

    expect(after, isNot(same(before)));
    final plan = after.plan('a *errand +errands @ben');
    expect(plan.labels.single.title, 'errand');
    expect(plan.project?.id, 5);
    expect(plan.assignees, [ben]);
  });

  test("after an account switch the previous account's rows are not "
      'planned with', () async {
    final container = containerWith();
    final subscription = container.listen(quickAddServiceProvider, (_, _) {});
    addTearDown(subscription.close);
    await pumpEventQueue();
    expect(subscription.read()!.plan('a +garage *wichtig').project, garage);

    final engine = FakeSyncEngine(clock: () => now);
    final other = sampleProject(id: 30, title: 'Other');
    container.updateOverrides([
      activeAccountIsGuestProvider.overrideWithValue(false),
      ...repositories(
        projects: FakeProjectRepository(engine)..all = [other],
        tasks: FakeTaskRepository(engine),
        labels: FakeLabelRepository(),
        users: FakeUserRepository(),
      ),
      userSettingsProvider.overrideWith(
        (ref) => Stream.value(const UserSettings()),
      ),
      clockProvider.overrideWithValue(() => now),
    ]);
    final switching = subscription.read()!.plan('a +garage *wichtig');
    expect(switching.project, isNull);
    expect(switching.labels, isEmpty);

    await pumpEventQueue();
    final switched = subscription.read()!.plan('a +garage *wichtig');
    expect(switched.unmatchedProject, 'garage');
    expect(switched.project, other);
    expect(switched.newLabels, ['wichtig']);
  });

  test("a link-share guest's submit neither searches people nor creates "
      'labels', () async {
    final container = containerWith(guest: true);

    final result = await (await serviceOf(container))
        .submit('Buy milk @ben *errand', fallbackProjectId: 3);

    expect(users.searches, isEmpty);
    expect(labels.created, isEmpty);
    expect(result.unresolvedAssignees, ['ben']);
    expect(result.labelsNotCreated, ['errand']);
  });

  test('submit creates through the task repository', () async {
    final container = containerWith();

    final result = await (await serviceOf(container))
        .submit('Buy milk *wichtig', fallbackProjectId: 3);

    expect(result.createdTaskIds, [-1]);
    expect(tasks.creates.single.projectId, 3);
    expect(tasks.updates.single.$2.labels?.added, {10});
  });
}
