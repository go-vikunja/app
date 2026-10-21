import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_mobile/core/attachments/attachment_image_providers.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/avatar/avatar_providers.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_details_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_resolver.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_details_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_resolver_providers.dart';
import 'package:vikunja_mobile/core/storage/comment_drafts.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/notification_fakes.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final noon = DateTime.utc(2026, 10, 19, 12);
  late AuthFakes auth;
  late ProviderContainer container;
  late Map<String, FakeSyncClient> readClients;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(
      () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
    );
    auth = AuthFakes();
    readClients = {};
    final files = FakeAccountDatabaseFiles();
    container = ProviderContainer(
      overrides: [
        ...auth.overrides,
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
      ],
    );
    addTearDown(container.dispose);
  });

  test('signed out there is nothing to read details, tasks or images '
      'with', () async {
    await container.read(accountsProvider.future);

    expect(container.read(taskDetailsRepositoryProvider), isNull);
    expect(container.read(taskResolverProvider), isNull);
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
    container
      ..listen(taskDetailsRepositoryProvider, (_, _) {})
      ..listen(taskResolverProvider, (_, _) {});

    final details = container.read(taskDetailsRepositoryProvider);
    final images = container.read(attachmentImagesProvider);
    expect(details, isA<LocalTaskDetailsRepository>());
    expect(container.read(taskResolverProvider), isA<LocalTaskResolver>());
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
}
