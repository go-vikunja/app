@Tags(['contract'])
@Timeout(Duration(minutes: 6))
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import 'helpers.dart';

// Capability.subscriptionOptOuts against the server: with it, unfollowing a
// task or subproject that a followed project covers opts just that one out;
// without it (before 2.6.0) the server refuses that with a 403 and the
// follow stays.
void main() {
  group(
    'opting out of a follow through a project on local Docker servers',
    skip: contractSkip,
    () {
      for (final (:port, :version) in contractServers) {
        group('$version on :$port', () {
          late Dio dio;
          late ServerConnection connection;
          late TestUser user;

          setUpAll(() async {
            dio = contractDio();
            connection = await DioServerConnector(dio)
                .connect('http://localhost:$port');
            user = await registerAndLogin(dio, connection);
          });

          tearDownAll(() => dio.close(force: true));

          test('the capability is there from 2.6.0', () {
            expect(
              connection.capabilities.has(Capability.subscriptionOptOuts),
              contractServerVersion.isAtLeast(2, 6),
            );
          });

          for (final apiVersion in ApiVersion.values) {
            group(apiVersion.pathSegment, skip: skipWithout(apiVersion), () {
              late VikunjaWriteClient writes;
              late VikunjaReadClient reads;
              late int projectId;
              late int childId;
              late int taskId;
              late Subscription throughProject;

              setUpAll(() async {
                final only = onlyVersion(connection, apiVersion);
                final authenticated = createAuthenticatedDio(
                  base: dio,
                  connection: only,
                  tokens: StaticJwt(user.jwt),
                );
                writes = createWriteClient(
                  dio: authenticated,
                  connection: only,
                );
                reads = createReadClient(dio: authenticated, connection: only);
                final projects = RetryingProjectsWrites(writes.projects);
                projectId = (await projects.create(
                  NewProject(title: 'Opt-outs ${apiVersion.pathSegment}'),
                )).id;
                childId = (await projects.create(
                  NewProject(
                    title: 'Opt-outs child ${apiVersion.pathSegment}',
                    parentProjectId: projectId,
                  ),
                )).id;
                // Created before the follow: from 2.6.0 the server makes its
                // creator follow a task directly.
                taskId = (await RetryingTasksWrites(
                  writes.tasks,
                ).create(NewTask(projectId: projectId, title: 'Covered'))).id;
                final own = await reads.subscriptions.forTask(taskId);
                if (own != null) {
                  await despiteWriteRaces(
                    () => writes.subscriptions.unsubscribe(
                      SubscriptionEntity.task,
                      taskId,
                    ),
                  );
                }
                await despiteWriteRaces(
                  () => writes.subscriptions.subscribe(
                    SubscriptionEntity.project,
                    projectId,
                  ),
                );
                throughProject = Subscription(
                  entity: SubscriptionEntity.project,
                  entityId: projectId,
                );
              });

              bool optOuts() =>
                  connection.capabilities.has(Capability.subscriptionOptOuts);

              test('a task the project covers', () async {
                expect(
                  await reads.subscriptions.forTask(taskId),
                  throughProject,
                );

                final unfollow = writes.subscriptions.unsubscribe(
                  SubscriptionEntity.task,
                  taskId,
                );

                if (optOuts()) {
                  await unfollow;
                  expect(await reads.subscriptions.forTask(taskId), isNull);
                } else {
                  await expectLater(unfollow, throwsA(isA<Forbidden>()));
                  expect(
                    await reads.subscriptions.forTask(taskId),
                    throughProject,
                  );
                }
                expect(
                  await reads.subscriptions.forProject(projectId),
                  throughProject,
                );
              });

              test('a subproject its parent covers', () async {
                expect(
                  await reads.subscriptions.forProject(childId),
                  throughProject,
                );

                final unfollow = writes.subscriptions.unsubscribe(
                  SubscriptionEntity.project,
                  childId,
                );

                if (optOuts()) {
                  await unfollow;
                  expect(await reads.subscriptions.forProject(childId), isNull);
                } else {
                  await expectLater(unfollow, throwsA(isA<Forbidden>()));
                  expect(
                    await reads.subscriptions.forProject(childId),
                    throughProject,
                  );
                }
                expect(
                  await reads.subscriptions.forProject(projectId),
                  throughProject,
                );
              });
            });
          }
        });
      }
    },
  );
}
