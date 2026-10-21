@Tags(['contract'])
@Timeout(Duration(minutes: 6))
library;

import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_details_repository.dart';
import 'package:vikunja_mobile/core/sync/sync_engine_impl.dart';

import '../helpers/test_database.dart';
import 'helpers.dart';

/// The SQLite server may answer "database is locked" right after a write.
Future<void> _pause() =>
    Future<void>.delayed(const Duration(milliseconds: 500));

/// A write link share of [projectId], signed in: someone else to comment,
/// without registering a second user.
Future<TestUser> _linkShare(
  Dio dio,
  ServerConnection connection,
  Seeder seeder,
  int projectId,
) async {
  final share = await seeder.post('/projects/$projectId/shares', {
    'permission': 1,
    'name': 'Neighbour',
  });
  final v1 = connection.apiBaseUri(ApiVersion.v1);
  final auth = await despiteWriteRaces(
    () => dio.postUri<Map<String, Object?>>(
      v1.replace(path: '${v1.path}/shares/${share['hash']}/auth'),
      data: <String, Object?>{},
    ),
  );
  return (id: 0, username: 'link-share', jwt: auth.data!['token']! as String);
}

// One user for the whole file: /register and /login share the limiter.
void main() {
  group(
    'comments, reactions and unread against the local Docker server',
    skip: contractSkip,
    () {
      late Dio dio;
      late ServerConnection connection;
      late TestUser user;
      late Seeder seeder;
      late Seeder neighbour;
      late int projectId;
      final run = Random.secure().nextInt(1 << 24).toRadixString(16);

      setUpAll(() async {
        dio = contractDio();
        connection = await DioServerConnector(dio)
            .connect('http://localhost:$contractServerPort');
        user = await registerAndLogin(dio, connection);
        seeder = Seeder(dio, connection, user);
        projectId = await seeder.create('/projects', {
          'title': 'Comments $run',
        });
        await _pause();
        neighbour = Seeder(
          dio,
          connection,
          await _linkShare(dio, connection, seeder, projectId),
        );
        await _pause();
      });

      tearDownAll(() => dio.close(force: true));

      for (final apiVersion in ApiVersion.values) {
        group('over ${apiVersion.pathSegment}', () {
          late VikunjaReadClient reads;
          late AppDatabase db;
          late LocalTaskDetailsRepository details;
          late Future<UserWithSettings> Function() currentUser;

          setUp(() {
            final only = onlyApiVersion(connection, apiVersion);
            final authenticated = createAuthenticatedDio(
              base: dio,
              connection: only,
              tokens: StaticJwt(user.jwt),
            );
            reads = createReadClient(dio: authenticated, connection: only);
            db = testDatabase();
            details = LocalTaskDetailsRepository(
              db,
              reads,
              createWriteClient(dio: authenticated, connection: only),
            );
            currentUser = AccountApi(
              authenticated,
              only,
            ).currentUserWithSettings;
          });

          Future<int> storedTask(String title) async {
            final id = await seeder.create('/projects/$projectId/tasks', {
              'title': '$title $run',
            });
            await _pause();
            await db.tasksDao.upsertAll([await reads.tasks.read(id)]);
            return id;
          }

          test("a comment written here is stored in the web's form with its "
              'mention, changed, reacted to and deleted, and the row '
              'counts it', () async {
            final taskId = await storedTask('Talked about');
            final name = user.username;
            final text = 'Thanks @$name & see https://vikunja.io\nDone.';
            final html = commentHtmlFromText(
              text,
              mentions: [
                MentionSpan(
                  start: 7,
                  end: 8 + name.length,
                  username: name,
                  label: name,
                ),
              ],
            );
            expect(
              html,
              contains(
                '<mention-user data-id="$name" data-label="$name" '
                'data-mention-suggestion-char="@"></mention-user>',
              ),
            );

            final written = await details.addComment(
              taskId,
              CommentDraft(html),
            );
            await _pause();

            expect(written.html, html);
            expect(written.author.username, name);
            expect((await db.tasksDao.find(taskId))!.commentCount, 1);
            final listed = (await details.comments(taskId)).items.single;
            expect(listed.id, written.id);
            expect(listed.html, html);
            final mention = parseRichText(
              listed.html,
              apiRoot: connection.rootUri,
              taskLinkBases: [connection.rootUri],
            ).blocks.first;
            expect(
              mention,
              isA<RichParagraph>().having(
                (p) => p.inlines.whereType<RichMention>().single.username,
                'mention',
                name,
              ),
            );

            final edited = await details.editComment(
              taskId,
              listed,
              CommentDraft(commentHtmlFromText('Done, really.')),
            );
            await _pause();
            expect(edited.html, '<p>Done, really.</p>');
            expect(edited.author.username, name);
            expect(edited.created, listed.created);

            await details.addReaction(ReactionEntity.task, taskId, '👍');
            await _pause();
            await details.addReaction(ReactionEntity.comment, edited.id, '🎉');
            await _pause();
            expect(
              (await details.details(taskId)).reactions['👍']!.single.username,
              name,
            );
            final reacted = (await details.comments(taskId)).items.single;
            expect(reacted.html, '<p>Done, really.</p>');
            expect(reacted.reactions.keys, ['🎉']);
            await details.removeReaction(
              ReactionEntity.comment,
              edited.id,
              '🎉',
            );
            await _pause();
            expect(
              (await details.comments(taskId)).items.single.reactions,
              isEmpty,
            );

            await details.deleteComment(taskId, edited.id);
            await _pause();
            await details.deleteComment(taskId, edited.id);
            await _pause();
            expect((await details.comments(taskId)).items, isEmpty);
            expect((await db.tasksDao.find(taskId))!.commentCount, 0);
          });

          test('a comment by someone else arrives with a sync as a count and '
              'an unread dot, which marking read clears on both '
              'ends', () async {
            final taskId = await storedTask('Asked about');
            final engine = DefaultSyncEngine(
              db: db,
              client: reads,
              perPage: 50,
              currentUser: currentUser,
            );
            addTearDown(engine.dispose);
            await engine.ensureInitialSync();
            expect((await db.tasksDao.find(taskId))!.commentCount, 0);

            await neighbour.post('/tasks/$taskId/comments', {
              'comment': '<p>Any news?</p>',
            });
            // The server marks the task unread after it answered.
            await Future<void>.delayed(const Duration(seconds: 1));
            await engine.refresh();

            final unread = (await db.tasksDao.find(taskId))!;
            expect(unread.commentCount, 1);
            expect(unread.isUnread, isTrue);

            await details.markRead(taskId);
            await _pause();
            expect((await db.tasksDao.find(taskId))!.isUnread, isFalse);
            expect((await details.details(taskId)).isUnread, isFalse);

            await engine.fullResync();
            final read = (await db.tasksDao.find(taskId))!;
            expect(read.commentCount, 1);
            expect(read.isUnread, isFalse);
          });
        });
      }
    },
  );
}
