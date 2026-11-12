@Tags(['contract'])
@Timeout(Duration(minutes: 10))
library;

import 'dart:math';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/link_share_gateway.dart';
import 'package:vikunja_mobile/core/auth/link_share_session.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/daos/kanban_dao.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/repositories/bucket_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_bucket_repository.dart';
import 'package:vikunja_mobile/core/sync/guest_read_client.dart';
import 'package:vikunja_mobile/core/sync/list_downloads.dart';
import 'package:vikunja_mobile/core/sync/sync_engine_impl.dart';
import 'package:vikunja_mobile/features/onboarding/application/guest_landing.dart';
import 'package:vikunja_mobile/features/onboarding/application/guest_sign_in.dart';
import 'package:vikunja_mobile/features/projects/application/project_access.dart';

import '../helpers/auth_fakes.dart';
import '../helpers/guest_fakes.dart';
import '../helpers/test_database.dart';
import 'helpers.dart';

/// The writes are paced, so that a SQLite server without the immediate
/// transactions of test_servers/docker-compose.yaml keeps up.
Future<void> _pace() => Future<void>.delayed(const Duration(milliseconds: 500));

/// Share authentication shares the sign-in limit per minute and IP with
/// every sign-in of every test file (10 unless raised, as
/// test_servers/docker-compose.yaml does): [GuestSignIn] reports a 429 as a result,
/// which is waited out here like [patiently] does for a thrown one.
Future<GuestSignInResult> _patiently(
  Future<GuestSignInResult> Function() signIn,
) async {
  for (var attempt = 1; ; attempt++) {
    final result = await signIn();
    if (result case GuestSignInFailed(failure: RateLimited(:final retryAfter))
        when attempt < 8) {
      await Future<void>.delayed(
        (retryAfter ?? const Duration(seconds: 10)) +
            Duration(seconds: 1 + Random().nextInt(3)),
      );
      continue;
    }
    // Paced like the sign-ins of the other files.
    await Future<void>.delayed(const Duration(seconds: 7));
    return result;
  }
}

/// A kanban view the owner created in the shared project, its buckets by
/// position: To-Do (the default), Doing and Done (the done bucket).
typedef _Board = ({int viewId, int toDo, int doing, int done});

/// A guest's synced account with a [_Board]'s board downloaded, and its
/// bucket repository; `fresh` downloads that board into a new database.
typedef _GuestBoard = ({
  AppDatabase db,
  LocalBucketRepository buckets,
  Future<StoredBoard> Function() fresh,
});

Future<void> _until(
  Future<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

// The acceptance of step 32: an owner shares a project through a read-only
// link and a password-protected writing link; each guest opens its link in
// the app, syncs, and is shaped by the share's permission; the writing
// guest's edit reaches the server; the token is renewed; and a deleted
// share ends the guest's session. Then the board's columns of D48 and D62:
// an admin link's guest and the writing guest change boards of their own
// through the app's bucket repository, and the server stores what the app
// assumes. One fresh user and five share authentications.
void main() {
  group(
    'link-share guests against the local Docker server',
    skip: contractSkip,
    () {
      late Dio dio;
      late ServerConnection connection;
      late TestUser owner;
      late Seeder seeder;
      late ProjectSharingPort sharing;
      late int projectId;
      late int taskId;
      late LinkShare readShare;
      late LinkShare writeShare;
      late LinkShare adminShare;
      late String password;
      late AuthFakes stores;
      late LinkShareGateway gateway;
      late GuestSignIn guestSignIn;
      late LinkShareSessions sessions;
      late RegisteredAccount readGuest;
      late RegisteredAccount writeGuest;
      late RegisteredAccount adminGuest;

      LinkShareSessions newSessions({DateTime Function()? clock}) =>
          LinkShareSessions(
            store: stores.linkShareStore,
            gateway: gateway,
            connectionFor: (id) async =>
                (await stores.registry.find(id))?.connection,
            markNeedsReauth: stores.registry.markNeedsReauth,
            clock: clock ?? DateTime.now,
          );

      // The link as the web and the app share it, taken apart again.
      ParsedLinkShareUrl linkOf(LinkShare share) => parseLinkShareUrl(
        linkShareUrl(
          base: webFrontendBase(
            serverRoot: connection.rootUri,
            frontendUrl: connection.info.frontendUrl,
          ),
          hash: share.hash,
        ).toString(),
      )!;

      Dio guestDio(
        String accountId,
        ApiVersion version, {
        LinkShareSessions? using,
      }) {
        final guestSessions = using ?? sessions;
        final client = createAuthenticatedDio(
          base: dio,
          connection: onlyApiVersion(connection, version),
          tokens: guestSessions.forAccount(accountId),
          interceptors: [
            LinkShareGoneInterceptor(
              onGone: (failure) =>
                  guestSessions.forAccount(accountId).noteGone(failure),
            ),
          ],
        );
        addTearDown(client.close);
        return client;
      }

      ({DefaultSyncEngine engine, AppDatabase db, Dio dio}) guestSync(
        RegisteredAccount guest,
        ApiVersion version, {
        LinkShareSessions? using,
      }) {
        final client = guestDio(guest.id, version, using: using);
        final db = testDatabase();
        addTearDown(db.close);
        final engine = DefaultSyncEngine(
          db: db,
          client: GuestReadClient(
            createReadClient(
              dio: client,
              connection: onlyApiVersion(connection, version),
            ),
            sharedProjectId: guest.account.projectId!,
          ),
          perPage: connection.info.maxItemsPerPage,
        );
        addTearDown(engine.dispose);
        return (engine: engine, db: db, dio: client);
      }

      Future<bool> needsReauth(String accountId) async =>
          (await stores.registry.find(accountId))!.account.needsReauth;

      Future<_Board> newBoard(String title) async {
        final viewId = await seeder.create('/projects/$projectId/views', {
          'title': title,
          'view_kind': 'kanban',
          'bucket_configuration_mode': 'manual',
        });
        await _pace();
        final buckets =
            (await seeder.get(
                  '/projects/$projectId/views/$viewId/buckets',
                ))['items']!
                as List<Object?>;
        final [toDo, doing, done] = [
          for (final bucket in buckets.cast<Map<String, Object?>>())
            bucket['id']! as int,
        ];
        return (viewId: viewId, toDo: toDo, doing: doing, done: done);
      }

      Future<({int done, int defaultId})> serverView(int viewId) async {
        final view = await seeder.get('/projects/$projectId/views/$viewId');
        return (
          done: view['done_bucket_id']! as int,
          defaultId: view['default_bucket_id']! as int,
        );
      }

      // Built for the guest's account as the app builds it, but without the
      // quiet board download after a change, so the stored board is the
      // write-through's alone.
      Future<_GuestBoard> guestBoard(
        RegisteredAccount guest,
        ApiVersion version,
        int viewId,
      ) async {
        final (:engine, :db, dio: client) = guestSync(guest, version);
        final only = onlyApiVersion(connection, version);
        final reads = createReadClient(dio: client, connection: only);
        Future<StoredBoard> download(AppDatabase into) async {
          await downloadBoard(
            db: into,
            client: reads,
            perPage: only.info.maxItemsPerPage,
            projectId: projectId,
            viewId: viewId,
            now: DateTime.now,
          );
          return await into.kanbanDao.load(viewId);
        }

        await engine.ensureInitialSync();
        await download(db);
        return (
          db: db,
          buckets: LocalBucketRepository(
            db,
            createWriteClient(dio: client, connection: only),
            refreshBoard: (_, _) async {},
          ),
          fresh: () {
            final fresh = testDatabase();
            addTearDown(fresh.close);
            return download(fresh);
          },
        );
      }

      Future<void> expectLikeServer(_GuestBoard guest, int viewId) async {
        final local = await guest.db.kanbanDao.load(viewId);
        final fresh = await guest.fresh();
        expect(local.buckets, fresh.buckets);
        expect(local.slots, fresh.slots);
        final view = await guest.db.projectsDao.loadView(viewId);
        expect((
          done: view?.doneBucketId,
          defaultId: view?.defaultBucketId,
        ), await serverView(viewId));
      }

      Future<void> act(Future<void> Function() action) async {
        await despiteWriteRaces(action);
        await _pace();
      }

      setUpAll(() async {
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        addTearDown(
          () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
        );
        dio = contractDio();
        connection = await DioServerConnector(dio)
            .connect('http://localhost:$contractServerPort');
        owner = await registerAndLogin(dio, connection);
        seeder = Seeder(dio, connection, owner);
        sharing = createProjectSharingPort(
          dio: createAuthenticatedDio(
            base: dio,
            connection: connection,
            tokens: StaticJwt(owner.jwt),
          ),
          connection: connection,
        );
        projectId = await seeder.create('/projects', {
          'title': 'Shared garden',
        });
        await _pace();
        taskId = await seeder.create('/projects/$projectId/tasks', {
          'title': 'Water the plants',
        });
        await _pace();
        password = 'guest-${Random.secure().nextInt(1 << 32)}';
        readShare = await sharing.createLinkShare(
          projectId,
          const NewLinkShare(permission: Permission.read, name: 'Guest RO'),
        );
        await _pace();
        writeShare = await sharing.createLinkShare(
          projectId,
          NewLinkShare(
            permission: Permission.write,
            name: 'Helper',
            password: password,
          ),
        );
        await _pace();
        adminShare = await sharing.createLinkShare(
          projectId,
          const NewLinkShare(permission: Permission.admin, name: 'Gardener'),
        );
        await _pace();
        stores = AuthFakes();
        gateway = ApiLinkShareGateway(dio);
        sessions = newSessions();
        guestSignIn = GuestSignIn(
          gateway: gateway,
          store: stores.linkShareStore,
          sessions: sessions,
          registry: stores.registry,
          connector: DioServerConnector(dio),
          landing: GuestLandings(),
          projectTitle: readSharedProjectTitle(dio),
        );
      });

      tearDownAll(() => dio.close(force: true));

      test('the read guest opens its link, and its syncs store the project '
          'read-only on both API versions', () async {
        final link = linkOf(readShare);
        final server = await guestSignIn.connect(link);
        expect(server.rootUri, connection.rootUri);

        final opened = await _patiently(() => guestSignIn.signIn(server, link));

        readGuest = (opened as GuestSignedIn).account;
        expect(readGuest.account.isLinkShare, isTrue);
        expect(readGuest.account.projectId, projectId);
        expect(readGuest.account.linkShareId, readShare.id);
        expect(readGuest.account.displayName, 'Guest RO');
        expect(
          (await stores.linkShareStore.read(readGuest.id))?.hash,
          readShare.hash,
        );
        for (final version in ApiVersion.values) {
          final (:engine, :db, dio: _) = guestSync(readGuest, version);
          await engine.ensureInitialSync();

          final stored = (await db.projectsDao.loadAll()).single;
          expect(stored.id, projectId, reason: version.name);
          expect(stored.maxPermission, Permission.read, reason: version.name);
          final access = ProjectAccess.of(stored);
          expect(access.isReadOnly, isTrue);
          expect(access.canWrite, isFalse);
          expect(access.canAddTasks, isFalse);
          expect(access.isAdmin, isFalse);
          expect((await db.tasksDao.find(taskId))?.title, 'Water the plants');
        }
      });

      test('the write guest needs its password, then its edit reaches the '
          'server through the outbox on both API versions', () async {
        final link = linkOf(writeShare);
        final server = await guestSignIn.connect(link);
        final asked = await _patiently(() => guestSignIn.signIn(server, link));
        expect(asked, isA<GuestPasswordRequired>());
        expect((asked as GuestPasswordRequired).wrongPassword, isFalse);

        final opened = await _patiently(
          () => guestSignIn.signIn(server, link, password: password),
        );

        writeGuest = (opened as GuestSignedIn).account;
        expect(writeGuest.account.displayName, 'Helper');
        expect(writeGuest.account.userId, -writeShare.id);
        expect([
          ...stores.secureStore.values.values,
          ...stores.preferences.values.values,
        ], everyElement(isNot(contains(password))));
        for (final version in ApiVersion.values) {
          final (:engine, :db, dio: client) = guestSync(writeGuest, version);
          await engine.ensureInitialSync();
          final stored = (await db.projectsDao.loadAll()).single;
          expect(stored.maxPermission, Permission.write, reason: version.name);
          expect(ProjectAccess.of(stored).canAddTasks, isTrue);
          expect(ProjectAccess.of(stored).isAdmin, isFalse);

          final only = onlyApiVersion(connection, version);
          final sender = OutboxSender(
            db: db,
            writeClient: createWriteClient(dio: client, connection: only),
            readClient: createReadClient(dio: client, connection: only),
            sync: engine,
            currentUserId: () => writeGuest.account.userId,
          );
          addTearDown(sender.dispose);
          final title = 'Watered by the helper over ${version.pathSegment}';
          await db.outboxDao.queueUpdate(
            taskId,
            TaskChanges(title: title),
            now: DateTime.now().toUtc(),
          );
          await sender.drain();
          await _until(() async => await db.outboxDao.count() == 0);

          final onServer = await seeder.get('/tasks/$taskId');
          expect(onServer['title'], title);
          expect((await db.tasksDao.find(taskId))?.title, title);
        }
      });

      test("the guest's token is renewed through POST /user/token once half "
          'its lifetime has passed, on both API versions', () async {
        for (final version in ApiVersion.values) {
          final stored = (await stores.linkShareStore.read(writeGuest.id))!;
          final before = LinkShareClaims.tryParse(stored.token!)!;
          // 40 h later on this device: past half of the 72 h.
          final later = newSessions(
            clock: () => DateTime.now().add(const Duration(hours: 40)),
          );
          await stores.registry.upsert(
            RegisteredAccount(
              account: writeGuest.account,
              connection: onlyApiVersion(connection, version),
            ),
          );

          final renewed = await later
              .forAccount(writeGuest.id)
              .validAccessToken();

          expect(renewed, isNot(stored.token), reason: version.name);
          final claims = LinkShareClaims.tryParse(renewed)!;
          expect(claims.shareId, writeShare.id);
          expect(claims.projectId, projectId);
          expect(claims.expiresAt.isBefore(before.expiresAt), isFalse);
          expect(
            (await stores.linkShareStore.read(writeGuest.id))?.token,
            renewed,
          );
          final project = await createReadClient(
            dio: createAuthenticatedDio(
              base: dio,
              connection: onlyApiVersion(connection, version),
              tokens: StaticJwt(renewed),
            ),
            connection: onlyApiVersion(connection, version),
          ).projects.read(projectId);
          expect(project.maxPermission, Permission.write);
          // Renewal is not on the sign-in limit; seconds apart, the next
          // token would carry the same claims.
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        await stores.registry.upsert(writeGuest);
      });

      test('a deleted share ends the guest session on both API versions, '
          'and its link no longer opens', () async {
        await sharing.deleteLinkShare(projectId, readShare.id);
        await _pace();

        for (final version in ApiVersion.values) {
          await stores.registry.upsert(readGuest);
          final fresh = newSessions();
          final (:engine, db: _, dio: _) = guestSync(
            readGuest,
            version,
            using: fresh,
          );

          await expectLater(
            engine.refresh(),
            throwsA(isA<LinkShareGone>()),
            reason: version.name,
          );
          await _until(() => needsReauth(readGuest.id));
          await expectLater(
            fresh.forAccount(readGuest.id).validAccessToken(),
            throwsA(isA<LinkShareGone>()),
          );
        }

        final reopened = await _patiently(
          () => guestSignIn.reopen(readGuest.id),
        );
        expect(reopened, isA<GuestLinkGone>());
        expect((reopened as GuestLinkGone).sharingOff, isFalse);
        expect(await stores.linkShareStore.read(readGuest.id), isNotNull);
      });

      test('the admin guest opens its link, and sets and clears the done and '
          'the default column, which the server stores, on both API '
          'versions', () async {
        final link = linkOf(adminShare);
        final server = await guestSignIn.connect(link);
        final opened = await _patiently(() => guestSignIn.signIn(server, link));
        adminGuest = (opened as GuestSignedIn).account;
        expect(adminGuest.account.linkShareId, adminShare.id);

        for (final version in ApiVersion.values) {
          final board = await newBoard('Admin ${version.pathSegment}');
          final guest = await guestBoard(adminGuest, version, board.viewId);
          final stored = (await guest.db.projectsDao.loadAll()).single;
          expect(stored.maxPermission, Permission.admin, reason: version.name);
          expect(
            ProjectAccess.of(stored).canChooseDoneAndDefaultColumn,
            isTrue,
          );

          await act(
            () => guest.buckets.setDoneBucket(
              projectId,
              board.viewId,
              board.doing,
            ),
          );
          await act(
            () => guest.buckets.setDefaultBucket(
              projectId,
              board.viewId,
              board.done,
            ),
          );

          expect(await serverView(board.viewId), (
            done: board.doing,
            defaultId: board.done,
          ), reason: version.name);
          await expectLikeServer(guest, board.viewId);

          await act(
            () => guest.buckets.setDoneBucket(projectId, board.viewId, null),
          );
          await act(
            () => guest.buckets.setDefaultBucket(projectId, board.viewId, null),
          );

          expect(await serverView(board.viewId), (
            done: 0,
            defaultId: 0,
          ), reason: version.name);
          await expectLikeServer(guest, board.viewId);
        }
      });

      test('the write guest is refused the done column, and the new default '
          'that deleting the leftmost column holding tasks needs while none '
          'is set, before anything is deleted, on both API versions', () async {
        for (final version in ApiVersion.values) {
          final board = await newBoard('Write ${version.pathSegment}');
          await seeder.patch('/projects/$projectId/views/${board.viewId}', {
            'default_bucket_id': 0,
          });
          await _pace();
          final guest = await guestBoard(writeGuest, version, board.viewId);
          final stored = (await guest.db.projectsDao.loadAll()).single;
          expect(stored.maxPermission, Permission.write, reason: version.name);
          expect(
            ProjectAccess.of(stored).canChooseDoneAndDefaultColumn,
            isFalse,
          );
          expect(
            (await guest.db.kanbanDao.load(board.viewId))
                .slots[taskId]
                ?.bucketId,
            board.toDo,
          );

          await expectLater(
            guest.buckets.setDoneBucket(projectId, board.viewId, board.doing),
            throwsA(isA<Forbidden>()),
            reason: version.name,
          );
          await _pace();
          await expectLater(
            guest.buckets.delete(projectId, board.viewId, board.toDo),
            throwsA(isA<NewDefaultRefused>()),
            reason: version.name,
          );
          await _pace();

          expect(await serverView(board.viewId), (
            done: board.done,
            defaultId: 0,
          ), reason: version.name);
          final fresh = await guest.fresh();
          expect(
            [for (final bucket in fresh.buckets) bucket.id],
            [board.toDo, board.doing, board.done],
            reason: version.name,
          );
          expect(fresh.slots[taskId]?.bucketId, board.toDo);
          await expectLikeServer(guest, board.viewId);
        }
      });

      test('the write guest deletes the done and then the default column, '
          'which the server clears in the view, and their tasks move where '
          'the app puts them, on both API versions', () async {
        for (final version in ApiVersion.values) {
          final board = await newBoard('Columns ${version.pathSegment}');
          final compost = await seeder.create('/projects/$projectId/tasks', {
            'title': 'Turn the compost',
          });
          await _pace();
          await seeder.put(
            '/projects/$projectId/views/${board.viewId}/buckets/'
            '${board.doing}/tasks',
            {'task_id': compost},
          );
          await _pace();
          final harvest = await seeder.create('/projects/$projectId/tasks', {
            'title': 'Harvest',
            'done': true,
          });
          await _pace();
          await seeder.patch('/projects/$projectId/views/${board.viewId}', {
            'default_bucket_id': board.doing,
          });
          await _pace();
          final guest = await guestBoard(writeGuest, version, board.viewId);
          final before = (await guest.db.kanbanDao.load(board.viewId)).slots;
          expect(
            (before[compost]?.bucketId, before[harvest]?.bucketId),
            (board.doing, board.done),
          );

          await act(
            () => guest.buckets.delete(projectId, board.viewId, board.done),
          );

          expect(await serverView(board.viewId), (
            done: 0,
            defaultId: board.doing,
          ), reason: version.name);
          expect(
            (await guest.db.kanbanDao.load(board.viewId))
                .slots[harvest]
                ?.bucketId,
            board.doing,
          );
          await expectLikeServer(guest, board.viewId);

          await act(
            () => guest.buckets.delete(projectId, board.viewId, board.doing),
          );

          expect(await serverView(board.viewId), (
            done: 0,
            defaultId: 0,
          ), reason: version.name);
          final after = (await guest.db.kanbanDao.load(board.viewId)).slots;
          expect(
            (after[compost]?.bucketId, after[harvest]?.bucketId),
            (board.toDo, board.toDo),
          );
          await expectLikeServer(guest, board.viewId);
        }
      });

      test('the server stores a default it no longer has as none: the admin '
          "guest's delete that needed it as the new default is a "
          'NewDefaultGone with the old default back, and setting it clears '
          'the default, on both API versions', () async {
        for (final version in ApiVersion.values) {
          final board = await newBoard('Gone ${version.pathSegment}');
          final guest = await guestBoard(adminGuest, version, board.viewId);
          expect(
            (await guest.db.kanbanDao.load(board.viewId))
                .slots[taskId]
                ?.bucketId,
            board.toDo,
          );
          // Deleted elsewhere since the guest's board download.
          await seeder.delete(
            '/projects/$projectId/views/${board.viewId}/buckets/${board.doing}',
          );
          await _pace();

          await expectLater(
            guest.buckets.delete(projectId, board.viewId, board.toDo),
            throwsA(
              isA<NewDefaultGone>()
                  .having((gone) => gone.bucket.id, 'bucket', board.toDo)
                  .having(
                    (gone) => gone.newDefault.id,
                    'newDefault',
                    board.doing,
                  ),
            ),
            reason: version.name,
          );
          await _pace();

          expect(await serverView(board.viewId), (
            done: board.done,
            defaultId: board.toDo,
          ), reason: version.name);
          expect(
            (await guest.db.projectsDao.loadView(board.viewId))
                ?.defaultBucketId,
            board.toDo,
          );
          final fresh = await guest.fresh();
          expect(
            [for (final bucket in fresh.buckets) bucket.id],
            [board.toDo, board.done],
            reason: version.name,
          );
          expect(fresh.slots[taskId]?.bucketId, board.toDo);

          await act(
            () => guest.buckets.setDefaultBucket(
              projectId,
              board.viewId,
              board.doing,
            ),
          );

          expect(
            (await guest.db.projectsDao.loadView(board.viewId))
                ?.defaultBucketId,
            0,
            reason: '${version.name}: the answer',
          );
          expect(await serverView(board.viewId), (
            done: board.done,
            defaultId: 0,
          ), reason: '${version.name}: stored');
        }
      });
    },
  );
}
