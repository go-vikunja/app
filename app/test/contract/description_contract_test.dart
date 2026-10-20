@Tags(['contract'])
@Timeout(Duration(minutes: 8))
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_repository.dart';
import 'package:vikunja_mobile/core/sync/sync_engine_impl.dart';

import '../helpers/test_database.dart';
import 'helpers.dart';

// Per API version, descriptions written through the repository and the
// outbox against the real server: an edit and a checkbox tap round-trip
// byte for byte; a change on the web between the queue and the send makes
// the tap apply to the web's description and the edit a conflict, which
// Keep mine and Use the web's resolve. One user for the whole file.
const _pace = Duration(milliseconds: 500);

String _item(String text, {required bool checked, String? id}) =>
    '<li data-checked="$checked" data-type="taskItem"'
    '${id == null ? '' : ' data-task-id="$id"'}><label><input type="checkbox"'
    '${checked ? ' checked="checked"' : ''}><span></span></label>'
    '<div><p>$text</p></div></li>';

String _list(List<String> items) =>
    '<ul data-type="taskList">${items.join()}</ul>';

Future<void> _until(
  Future<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

void main() {
  group(
    'descriptions through the outbox against the local Docker server',
    skip: contractSkip,
    () {
      late Dio dio;
      late ServerConnection connection;
      late TestUser user;
      late Seeder seeder;

      setUpAll(() async {
        dio = contractDio();
        connection = await DioServerConnector(dio)
            .connect('http://localhost:$contractServerPort');
        user = await registerAndLogin(dio, connection);
        seeder = Seeder(dio, connection, user);
      });

      tearDownAll(() => dio.close(force: true));

      for (final apiVersion in ApiVersion.values) {
        group('over ${apiVersion.pathSegment}', () {
          late VikunjaReadClient reads;
          late AppDatabase db;
          late OutboxSender sender;
          late LocalTaskRepository repository;
          late int projectId;

          Future<int> seedTask(String description) async {
            final id = await seeder.create('/projects/$projectId/tasks', {
              'title': 'Described',
              'description': description,
            });
            await Future<void>.delayed(_pace);
            return id;
          }

          /// A change made on the web meanwhile.
          Future<void> changeOnTheWeb(int taskId, String description) async {
            await seeder.patch('/tasks/$taskId', {'description': description});
            await Future<void>.delayed(_pace);
          }

          Future<String> local(int taskId) async =>
              (await db.tasksDao.find(taskId))!.description;

          Future<String> onServer(int taskId) async =>
              (await patiently(() => reads.tasks.read(taskId))).description;

          Future<void> sendAll() async {
            await sender.sendNow();
            await _until(() async => await db.outboxDao.count() == 0);
            await Future<void>.delayed(_pace);
          }

          Future<void> sendUntilProblem() async {
            await sender.sendNow();
            await _until(
              () async => (await db.outboxDao.loadProblems()).isNotEmpty,
            );
          }

          Future<bool> tap(
            int taskId,
            String text, {
            required bool checked,
          }) async {
            final html = await local(taskId);
            final item = parseRichText(
              html,
              apiRoot: connection.rootUri,
              taskLinkBases: const [],
            ).taskItems.firstWhere((item) => checklistItemText(item) == text);
            return await repository.toggleChecklistItem(
              taskId,
              html: html,
              item: item,
              checked: checked,
            );
          }

          setUpAll(() async {
            projectId = await seeder.create('/projects', {
              'title': 'Descriptions ${apiVersion.pathSegment}',
            });
            final only = onlyApiVersion(connection, apiVersion);
            final authenticated = createAuthenticatedDio(
              base: dio,
              connection: only,
              tokens: StaticJwt(user.jwt),
            );
            reads = createReadClient(dio: authenticated, connection: only);
            final writes = createWriteClient(
              dio: authenticated,
              connection: only,
            );
            db = testDatabase();
            final engine = DefaultSyncEngine(
              db: db,
              client: reads,
              perPage: only.info.maxItemsPerPage,
              currentUser: AccountApi(
                authenticated,
                only,
              ).currentUserWithSettings,
            );
            addTearDown(engine.dispose);
            sender = OutboxSender(
              db: db,
              writeClient: writes,
              readClient: reads,
              sync: engine,
            );
            addTearDown(sender.dispose);
            repository = LocalTaskRepository(
              db,
              engine,
              sender,
              writes,
              read: reads,
            );
            addTearDown(repository.dispose);
          });

          Future<void> syncIn(int taskId) async {
            await db.tasksDao.upsertAll([
              await patiently(() => reads.tasks.read(taskId)),
            ], syncRunId: 'contract');
          }

          test('an edit in the editor round-trips byte for byte', () async {
            final id = await seedTask('<p>Start</p>');
            await syncIn(id);
            final html =
                '<h2>Plan \u{1F600}</h2><p>one\r\ntwo</p>'
                '${_list([_item('Milk', checked: false, id: 'x1')])}<p></p>';

            await repository.updateDescription(id, html, base: '<p>Start</p>');
            expect(await local(id), html);
            await sendAll();

            expect(await onServer(id), html);
            expect(await local(id), html);
          });

          test('a checkbox tap changes only that checkbox, on the server '
              'too', () async {
            final original = _list([
              _item('Milk', checked: false, id: 'a'),
              _item('Eggs', checked: false),
            ]);
            final id = await seedTask(original);
            await syncIn(id);

            expect(await tap(id, 'Eggs', checked: true), isTrue);
            await sendAll();

            final expected = _list([
              _item('Milk', checked: false, id: 'a'),
              _item('Eggs', checked: true),
            ]);
            expect(await onServer(id), expected);
            expect(await local(id), expected);
            expect(
              checklistStatistics(await onServer(id)),
              const ChecklistStatistics(total: 2, checked: 1),
            );
          });

          test('taps queued before a change on the web are applied to the '
              "web's description", () async {
            final id = await seedTask(
              _list([
                _item('Milk', checked: false, id: 'a'),
                _item('Eggs', checked: false),
              ]),
            );
            await syncIn(id);
            sender.pause();
            expect(await tap(id, 'Milk', checked: true), isTrue);
            expect(await tap(id, 'Eggs', checked: true), isTrue);
            await changeOnTheWeb(
              id,
              '<p>Saturday</p>${_list([_item('Milk', checked: false, id: 'a'), _item('Eggs', checked: false), _item('Bread', checked: false, id: 'c')])}',
            );

            await sender.resume();
            await sendAll();

            final expected =
                '<p>Saturday</p>${_list([_item('Milk', checked: true, id: 'a'), _item('Eggs', checked: true), _item('Bread', checked: false, id: 'c')])}';
            expect(await onServer(id), expected);
            expect(await local(id), expected);
            expect(await db.outboxDao.loadProblems(), isEmpty);
          });

          test('an edit after a change on the web is a conflict; Keep mine '
              'overwrites it', () async {
            final id = await seedTask('<p>Start</p>');
            await syncIn(id);
            sender.pause();
            await repository.updateDescription(
              id,
              '<p>Mine</p>',
              base: '<p>Start</p>',
            );
            await changeOnTheWeb(id, '<p>Web</p>');

            await sender.resume();
            await sendUntilProblem();

            final problem = (await db.outboxDao.loadProblems()).single;
            expect(problem.failure, isA<DescriptionConflict>());
            expect(problem.taskId, id);
            expect(await onServer(id), '<p>Web</p>');
            expect(await local(id), '<p>Mine</p>');

            final web = await repository.webDescription(problem.operationId);
            expect(web, '<p>Web</p>');
            await repository.keepMyDescription(
              problem.operationId,
              webDescription: web!,
            );
            await _until(() async => await db.outboxDao.count() == 0);

            expect(await onServer(id), '<p>Mine</p>');
            expect(await local(id), '<p>Mine</p>');
          });

          test("an edit after a change on the web is a conflict; Use the web's "
              'keeps the web change', () async {
            final id = await seedTask('<p>Start</p>');
            await syncIn(id);
            sender.pause();
            await repository.updateDescription(
              id,
              '<p>Mine</p>',
              base: '<p>Start</p>',
            );
            await repository.setFavorite(id, favorite: true);
            await changeOnTheWeb(id, '<p>Web</p>');

            await sender.resume();
            await sendUntilProblem();
            final problem = (await db.outboxDao.loadProblems()).single;

            await repository.useWebDescription(problem.operationId);
            await _until(() async => await db.outboxDao.count() == 0);

            final stored = await patiently(() => reads.tasks.read(id));
            expect(stored.description, '<p>Web</p>');
            expect(stored.isFavorite, isTrue);
            final row = (await db.tasksDao.find(id))!;
            expect(row.description, '<p>Web</p>');
            expect(row.isFavorite, isTrue);
          });
        });
      }
    },
  );
}
