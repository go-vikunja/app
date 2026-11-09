@Tags(['contract'])
@Timeout(Duration(minutes: 10))
library;

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart'
    show OwnTaskSubscription, SubscribedTasks;
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/notification_plan.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences.dart';
import 'package:vikunja_mobile/core/repositories/local/local_subscription_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_details_repository.dart';
import 'package:vikunja_mobile/core/sync/sync_engine_impl.dart';

import '../helpers/test_database.dart';
import 'helpers.dart';

typedef _Side = ({
  TestUser user,
  AppDatabase db,
  DefaultSyncEngine engine,
  VikunjaReadClient reads,
  VikunjaWriteClient writes,
  Seeder seeder,
  LocalSubscriptionRepository subscriptions,
  LocalTaskDetailsRepository details,
});

Future<void> _sleepUntil(DateTime instant) async {
  final wait = instant.difference(DateTime.now());
  if (wait > Duration.zero) await Future<void>.delayed(wait);
}

// The acceptance of step 37g (D80): on 2.8.0 the follow state the app reads
// is stored per task and project, and the device plans the reminders of
// exactly the tasks the server's cron reminds each user of. Two users: the
// owner shares two projects with the follower.
void main() {
  group(
    'reminders that follow subscriptions against the local Docker server',
    skip: contractSkip,
    () {
      late Dio dio;
      late ServerConnection connection;
      late _Side owner;
      late _Side follower;
      late int followed;
      late int child;
      late int elsewhere;
      late int optedOut;
      late int unfollowedByOwner;
      late int followersOwn;
      late int inChild;
      late int assigned;
      late int followedTask;
      late Map<int, OwnTaskSubscription> ownersBeforeSync;
      late Map<int, OwnTaskSubscription> followersBeforeSync;

      bool skippedBelow28() {
        if (connection.capabilities.has(Capability.remindersToSubscribers)) {
          return false;
        }
        markTestSkipped('Reminders follow subscriptions from Vikunja 2.8');
        return true;
      }

      Future<_Side> signIn() async {
        final user = await registerAndLogin(dio, connection);
        final authenticated = createAuthenticatedDio(
          base: dio,
          connection: connection,
          tokens: StaticJwt(user.jwt),
        );
        final reads = createReadClient(
          dio: authenticated,
          connection: connection,
        );
        final writes = createWriteClient(
          dio: authenticated,
          connection: connection,
        );
        final db = testDatabase();
        final engine = DefaultSyncEngine(
          db: db,
          client: reads,
          perPage: connection.info.maxItemsPerPage,
          currentUser: AccountApi(
            authenticated,
            connection,
          ).currentUserWithSettings,
        );
        addTearDown(engine.dispose);
        return (
          user: user,
          db: db,
          engine: engine,
          reads: reads,
          writes: writes,
          seeder: Seeder(dio, connection, user),
          subscriptions: LocalSubscriptionRepository(
            db,
            reads,
            writes,
            subscriberId: user.id,
            refreshAfterWrite: engine.refreshAfterWrite,
          ),
          details: LocalTaskDetailsRepository(
            db,
            reads,
            writes,
            subscriberId: user.id,
          ),
        );
      }

      setUpAll(() async {
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        addTearDown(
          () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
        );
        dio = contractDio();
        connection = await DioServerConnector(dio)
            .connect('http://localhost:$contractServerPort');
        if (!connection.capabilities.has(Capability.remindersToSubscribers)) {
          return;
        }
        owner = await signIn();
        follower = await signIn();

        final seeder = owner.seeder;
        followed = await seeder.create('/projects', {'title': 'Followed'});
        child = await seeder.create('/projects', {
          'title': 'Followed child',
          'parent_project_id': followed,
        });
        elsewhere = await seeder.create('/projects', {'title': 'Elsewhere'});
        for (final project in [followed, elsewhere]) {
          await seeder.post('/projects/$project/users', {
            'username': follower.user.username,
            'permission': 1,
          });
        }
        Future<int> task(Seeder by, int project, String title) =>
            by.create('/projects/$project/tasks', {'title': title});
        optedOut = await task(seeder, followed, 'Opted out');
        unfollowedByOwner = await task(seeder, followed, 'Unfollowed');
        followersOwn = await task(follower.seeder, followed, "Follower's");
        inChild = await task(seeder, child, 'In the child');
        assigned = await task(seeder, followed, 'Assigned');
        followedTask = await task(seeder, elsewhere, 'Followed task');
        await seeder.post('/tasks/$assigned/assignees', {
          'user_id': follower.user.id,
        });
        await owner.engine.ensureInitialSync();
        await follower.engine.ensureInitialSync();

        await despiteWriteRaces(
          () => follower.subscriptions.setProjectSubscribed(
            followed,
            subscribed: true,
          ),
        );
        await despiteWriteRaces(
          () => follower.subscriptions.setTaskSubscribed(
            optedOut,
            subscribed: false,
          ),
        );
        await despiteWriteRaces(
          () => owner.subscriptions.setTaskSubscribed(
            unfollowedByOwner,
            subscribed: false,
          ),
        );
        await despiteWriteRaces(
          () => follower.subscriptions.setTaskSubscribed(
            followedTask,
            subscribed: true,
          ),
        );
        await despiteWriteRaces(() => follower.details.details(inChild));
        ownersBeforeSync = await owner.db.tasksDao.ownSubscriptions();
        followersBeforeSync = await follower.db.tasksDao.ownSubscriptions();
        await owner.engine.refreshAfterWrite();
        await follower.engine.refreshAfterWrite();
      });

      tearDownAll(() => dio.close(force: true));

      Set<int> ours() => {
        optedOut,
        unfollowedByOwner,
        followersOwn,
        inChild,
        assigned,
        followedTask,
      };

      test('what the reads and toggles said is stored per task and per '
          'project, and a sync keeps it', () async {
        if (skippedBelow28()) return;
        final followersExpected = {
          optedOut: OwnTaskSubscription.optedOut,
          inChild: OwnTaskSubscription.none,
          followedTask: OwnTaskSubscription.subscribed,
        };
        final ownersExpected = {unfollowedByOwner: OwnTaskSubscription.none};

        expect(followersBeforeSync, followersExpected);
        expect(ownersBeforeSync, ownersExpected);
        expect(
          await follower.db.tasksDao.ownSubscriptions(),
          followersExpected,
        );
        expect(await owner.db.tasksDao.ownSubscriptions(), ownersExpected);

        Future<Subscription?> via(_Side side, int project) async =>
            (await side.db.projectsDao.loadProject(project))!.subscription;
        final throughFollowed = Subscription(
          entity: SubscriptionEntity.project,
          entityId: followed,
        );
        expect(await via(follower, followed), throughFollowed);
        expect(
          await via(follower, child),
          throughFollowed,
          reason: 'a child names the followed parent',
        );
        expect(await via(follower, elsewhere), isNull);
        for (final project in [followed, child, elsewhere]) {
          expect(await via(owner, project), isNull);
        }
      });

      test("each user's task.reminder notifications from the server are the "
          'reminders the device plans', () async {
        if (skippedBelow28()) return;
        // The cron runs at second 00 and sends what is due within the next
        // minute; the half minute keeps the reminder inside one run.
        final now = DateTime.now().toUtc();
        final fire = DateTime.utc(
          now.year,
          now.month,
          now.day,
          now.hour,
          now.minute,
        ).add(const Duration(minutes: 2, seconds: 30));
        final reminder = TaskChanges(reminders: [TaskReminder(reminder: fire)]);
        for (final (side, ids) in [
          (
            owner,
            [optedOut, unfollowedByOwner, inChild, assigned, followedTask],
          ),
          (follower, [followersOwn]),
        ]) {
          for (final id in ids) {
            await despiteWriteRaces(
              () => side.writes.tasks.update(id, reminder),
            );
          }
        }
        await owner.engine.refreshAfterWrite();
        await follower.engine.refreshAfterWrite();

        Future<Set<int>> planned(_Side side) async {
          final db = side.db;
          final plan = planNotifications(
            tasks: await db.tasksDao.loadOpenTasks(),
            userId: side.user.id,
            preferences: const NotificationPreferences(),
            now: DateTime.now(),
            snoozes: const [],
            describe: (_, _) => (title: '', body: ''),
            subscribed: SubscribedTasks(
              own: await db.tasksDao.ownSubscriptions(),
              followedProjects: {
                for (final project in await db.projectsDao.loadAll())
                  if (project.subscription != null) project.id,
              },
            ),
          );
          final reminders = [
            for (final entry in plan)
              if (entry.kind == ScheduledNotificationKind.reminder) entry,
          ];
          expect(reminders.map((entry) => entry.fireAt.toUtc()).toSet(), {
            fire,
          });
          return {for (final entry in reminders) entry.taskId};
        }

        final ownersPlan = await planned(owner);
        final followersPlan = await planned(follower);
        expect(ownersPlan, {optedOut, inChild, assigned, followedTask});
        expect(followersPlan, {
          unfollowedByOwner,
          followersOwn,
          inChild,
          assigned,
          followedTask,
        });

        Future<Set<int>> reminded(_Side side) async {
          final page = await patiently(
            () => side.reads.notifications.list(perPage: 50),
          );
          return {
            for (final notification in page.items)
              if (notification.name == 'task.reminder' &&
                  ours().contains(notification.taskId))
                notification.taskId!,
          };
        }

        await _sleepUntil(fire.subtract(const Duration(seconds: 30)));
        final deadline = fire.add(const Duration(seconds: 40));
        final remindedOwner = <int>{};
        final remindedFollower = <int>{};
        while (true) {
          remindedOwner.addAll(await reminded(owner));
          remindedFollower.addAll(await reminded(follower));
          if (!DateTime.now().isBefore(deadline)) break;
          await Future<void>.delayed(const Duration(seconds: 5));
        }

        expect(remindedOwner, ownersPlan, reason: "the owner's reminders");
        expect(
          remindedFollower,
          followersPlan,
          reason: "the follower's reminders",
        );
      });
    },
  );
}
