import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart' show OwnTaskSubscription;
import 'package:vikunja_mobile/core/attachments/attachment_downloads.dart';
import 'package:vikunja_mobile/core/attachments/attachment_image_providers.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/avatar/avatar_providers.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_details_repository.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/subscription_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_details_repository_providers.dart';
import 'package:vikunja_mobile/core/storage/comment_drafts.dart';
import 'package:vikunja_mobile/core/widgets/widget_providers.dart';
import 'package:vikunja_mobile/features/description_editor/application/description_drafts.dart';
import 'package:vikunja_mobile/features/description_editor/application/description_target.dart';
import 'package:vikunja_mobile/features/session/application/sign_out_providers.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/guest_fakes.dart';
import '../../helpers/notification_fakes.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';
import '../../helpers/widget_fakes.dart';

void main() {
  final noon = DateTime.utc(2026, 10, 19, 12);
  late AuthFakes auth;
  late ProviderContainer container;
  late Map<String, FakeSyncClient> readClients;
  late AttachmentDownloads downloads;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(
      () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
    );
    auth = AuthFakes();
    readClients = {};
    final cache = Directory.systemTemp.createTempSync('details_providers');
    addTearDown(() => cache.deleteSync(recursive: true));
    downloads = AttachmentDownloads(() async => cache);
    final files = FakeAccountDatabaseFiles();
    container = ProviderContainer(
      overrides: [
        ...auth.overrides,
        attachmentDownloadsProvider.overrideWithValue(downloads),
        accountDatabaseFilesProvider.overrideWithValue(files),
        openDatabasesProvider.overrideWithValue(
          OpenDatabases(
            files,
            open: (_, _) => AppDatabase(NativeDatabase.memory()),
          ),
        ),
        readClientProvider.overrideWith(
          (ref, accountId) =>
              readClients.putIfAbsent(accountId, FakeSyncClient.new),
        ),
        writeClientProvider.overrideWith((ref, _) => FakeWriteClient()),
        syncEngineProvider.overrideWith((ref, _) => FakeSyncEngine()),
        notificationGatewayProvider.overrideWithValue(
          FakeNotificationGateway(),
        ),
        widgetHostProvider.overrideWithValue(FakeWidgetHost()),
      ],
    );
    addTearDown(container.dispose);
  });

  test('signed out there is nothing to read details or images with', () async {
    await container.read(accountsProvider.future);

    expect(container.read(taskDetailsRepositoryProvider), isNull);
    expect(container.read(attachmentImagesProvider), isNull);
  });

  test('they follow the active account', () async {
    final alice = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: noon),
    );
    final bob = await auth.seedAccount(
      oauthServer230(),
      tokens: issueTokens(issuedAt: noon, userId: 8, username: 'bob'),
      activate: false,
    );
    await container.read(accountsProvider.future);
    container.listen(taskDetailsRepositoryProvider, (_, _) {});

    final details = container.read(taskDetailsRepositoryProvider);
    final images = container.read(attachmentImagesProvider);
    expect(details, isA<LocalTaskDetailsRepository>());
    expect(
      images,
      same(container.read(accountAttachmentImagesProvider(alice.id))),
    );

    await container.read(accountRegistryProvider).setActive(bob.id);
    await pumpEventQueue();

    expect(
      container.read(taskDetailsRepositoryProvider),
      allOf(isNotNull, isNot(same(details))),
    );
    expect(
      container.read(attachmentImagesProvider),
      same(container.read(accountAttachmentImagesProvider(bob.id))),
    );
  });

  group("the follow state the account's reads record "
      '(decision log: Notifications and widgets)', () {
    const ownRow = Subscription(entity: SubscriptionEntity.task, entityId: 1);

    Future<AppDatabase> seedTask(RegisteredAccount entry) async {
      final task = sampleTask(id: 1, title: 'Read');
      final db = container.read(appDatabaseProvider(entry.id));
      await db.tasksDao.upsertAll([task]);
      readClients.putIfAbsent(entry.id, FakeSyncClient.new)
        ..allTasks = [task]
        ..taskSubscriptions[1] = ownRow;
      return db;
    }

    test("a task's details record the user's own subscription on 2.8.0; on "
        '2.7.0 and for a link-share guest nothing is recorded', () async {
      final alice = await auth.seedAccount(
        fullServer280(),
        tokens: issueTokens(issuedAt: noon),
      );
      final bob = await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: noon, userId: 8, username: 'bob'),
        activate: false,
      );
      final guest = await auth.seedGuest(
        fullServer280(root: 'https://other.example.org'),
        token: null,
        activate: false,
      );
      await container.read(accountsProvider.future);
      final databases = {
        for (final entry in [alice, bob, guest])
          entry.id: await seedTask(entry),
      };

      await container.read(taskDetailsRepositoryProvider)!.details(1);
      for (final entry in [bob, guest]) {
        await container
            .read(accountTaskDetailsRepositoryProvider(entry.id))
            .details(1);
      }

      expect(await databases[alice.id]!.tasksDao.ownSubscriptions(), {
        1: OwnTaskSubscription.subscribed,
      });
      expect(await databases[bob.id]!.tasksDao.ownSubscriptions(), isEmpty);
      expect(await databases[guest.id]!.tasksDao.ownSubscriptions(), isEmpty);
    });

    test("the bell's reads record on 2.8.0 only; a project's toggle starts "
        "the account's quiet refresh", () async {
      final alice = await auth.seedAccount(
        fullServer280(),
        tokens: issueTokens(issuedAt: noon),
      );
      final bob = await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: noon, userId: 8, username: 'bob'),
        activate: false,
      );
      await container.read(accountsProvider.future);
      final aliceDb = await seedTask(alice);
      final bobDb = await seedTask(bob);
      final subscriptions = container.read(subscriptionRepositoryProvider)!;

      await subscriptions.forTask(1);
      await container
          .read(accountSubscriptionRepositoryProvider(bob.id))
          .forTask(1);
      await subscriptions.setProjectSubscribed(1, subscribed: true);

      expect(await aliceDb.tasksDao.ownSubscriptions(), {
        1: OwnTaskSubscription.subscribed,
      });
      expect(await bobDb.tasksDao.ownSubscriptions(), isEmpty);
      final engine = container.read(syncEngineProvider(alice.id));
      expect((engine as FakeSyncEngine).refreshAfterWriteCalls, 1);
    });
  });

  test('attachment images load through the account read client', () async {
    final alice = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: noon),
    );
    await container.read(accountsProvider.future);
    final client =
        container.read(readClientProvider(alice.id)) as FakeSyncClient;
    client.attachmentBlobs[(4, 2, AttachmentPreviewSize.medium)] =
        AttachmentBlob(bytes: Uint8List(3), contentType: 'image/png');

    final image = await container
        .read(accountAttachmentImagesProvider(alice.id))
        .load(4, 2, preview: AttachmentPreviewSize.medium);

    expect(image.bytes, hasLength(3));
    expect(client.requests, ['attachment 4 2 md']);
  });

  test('an original in the download cache loads from there, offline too, '
      'found by the attachment stored with its task', () async {
    final alice = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: noon),
    );
    await container.read(accountsProvider.future);
    final db = container.read(appDatabaseProvider(alice.id));
    await db.tasksDao.upsertAll([sampleTask(id: 4, title: 'Fly')]);
    final pass = sampleAttachment(id: 2, taskId: 4, name: 'pass.png', size: 3);
    final ticket = sampleAttachment(id: 6, taskId: 4, size: 3);
    await db.taskDetailsDao.storeDetails(
      4,
      TaskDetails(attachments: [pass, ticket]),
      at: noon,
    );
    for (final (attachment, bytes) in [
      (pass, const [1, 2, 3]),
      (ticket, const [1, 2]),
    ]) {
      (await downloads.fileFor(alice.id, 4, attachment))
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);
    }
    final client =
        container.read(readClientProvider(alice.id)) as FakeSyncClient
          ..beforeRequest = (_) async =>
              throw const NetworkFailure(NetworkProblem.unreachable);
    final images = container.read(accountAttachmentImagesProvider(alice.id));

    final original = await images.load(4, 2);
    expect(original.bytes, const [1, 2, 3]);
    expect(original.contentType, 'image/png');
    expect(client.requests, isEmpty);

    for (final (attachmentId, preview) in [
      (2, AttachmentPreviewSize.medium),
      (6, null),
      (7, null),
    ]) {
      await expectLater(
        images.load(4, attachmentId, preview: preview),
        throwsA(isA<NetworkFailure>()),
      );
    }
    expect(client.requests, [
      'attachment 4 2 md',
      'attachment 4 6 original',
      'attachment 4 7 original',
    ]);
  });

  test("an account's own reactions are stored under its user as the server "
      'lists people', () async {
    final alice = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: noon),
    );
    final bob = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: noon, userId: 8, username: 'bob'),
      displayName: 'bob',
      activate: false,
    );
    await container.read(accountsProvider.future);
    final stored = <String, Reactions>{};
    for (final entry in [alice, bob]) {
      final task = sampleTask(id: 1, title: 'Read');
      await container.read(appDatabaseProvider(entry.id)).tasksDao.upsertAll([
        task,
      ]);
      readClients.putIfAbsent(entry.id, FakeSyncClient.new)
        ..allTasks = [task]
        ..taskDetails[1] = const TaskDetails();
      final repository = container.read(
        accountTaskDetailsRepositoryProvider(entry.id),
      );
      await repository.details(1);
      await repository.addReaction(ReactionEntity.task, 1, '👍');
      stored[entry.id] = (await repository.storedDetails(1))!.value.reactions;
    }

    expect(stored[alice.id], {
      '👍': [const User(id: 7, username: 'alice', name: 'Alice Example')],
    });
    expect(stored[bob.id], {
      '👍': [const User(id: 8, username: 'bob')],
    });
  });

  test("another account's activation empties the attachment images in "
      'memory', () async {
    final alice = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: noon),
    );
    final bob = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: noon, userId: 8, username: 'bob'),
      activate: false,
    );
    await container.read(accountsProvider.future);
    final client =
        container.read(readClientProvider(alice.id)) as FakeSyncClient;
    client.attachmentBlobs[(4, 2, null)] = AttachmentBlob(
      bytes: Uint8List(3),
      contentType: 'image/png',
    );
    container.listen(inactiveAttachmentImagesProvider, (_, _) {});
    final images = container.read(accountAttachmentImagesProvider(alice.id));
    await images.load(4, 2);
    expect(images.peek(4, 2), isNotNull);

    await container.read(accountRegistryProvider).setActive(bob.id);
    await pumpEventQueue();

    expect(images.peek(4, 2), isNull);
  });

  test('signing out drops the account avatars and attachment images from '
      'memory', () async {
    final alice = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: noon),
    );
    await container.read(accountsProvider.future);
    final client =
        container.read(readClientProvider(alice.id)) as FakeSyncClient;
    client.attachmentBlobs[(4, 2, null)] = AttachmentBlob(
      bytes: Uint8List(3),
      contentType: 'image/png',
    );
    final images = container.read(accountAttachmentImagesProvider(alice.id));
    final avatars = container.read(accountAvatarCacheProvider(alice.id));
    await images.load(4, 2);
    expect(images.peek(4, 2), isNotNull);

    await container.read(accountDataWiperProvider)(alice.id);

    expect(images.peek(4, 2), isNull);
    expect(
      container.read(accountAttachmentImagesProvider(alice.id)),
      isNot(same(images)),
    );
    expect(
      container.read(accountAvatarCacheProvider(alice.id)),
      isNot(same(avatars)),
    );
  });

  test("signing out drops the account's unsent comments only", () async {
    final alice = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: noon),
    );
    await container.read(accountsProvider.future);
    final drafts = container.read(commentDraftsProvider);
    const draft = CommentComposerDraft(text: 'Half written');
    await drafts.save(draft, account: alice.id, taskId: 3);
    await drafts.save(draft, account: 'someone-else', taskId: 3);

    await container.read(accountDataWiperProvider)(alice.id);

    expect(await drafts.read(account: alice.id, taskId: 3), isNull);
    expect(await drafts.read(account: 'someone-else', taskId: 3), draft);
  });

  test("signing out drops the account's description draft only", () async {
    final alice = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: noon),
    );
    await container.read(accountsProvider.future);
    final drafts = container.read(descriptionDraftsProvider);
    const target = TaskDescriptionTarget(3);
    const draft = DescriptionDraft(html: '<p>Half written</p>', base: '');
    final wipe = container.read(accountDataWiperProvider);

    await drafts.save(draft, account: 'someone-else', target: target);
    await drafts.save(draft, account: alice.id, target: target);
    await wipe(alice.id);

    expect(await drafts.read(account: alice.id, target: target), isNull);
    expect(
      await drafts.read(account: 'someone-else', target: target),
      isNotNull,
    );
  });
}
