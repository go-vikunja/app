import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/attachments/attachment_image_providers.dart';
import 'package:vikunja_mobile/core/attachments/image_disk_cache.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/sign_out_providers.dart';
import 'package:vikunja_mobile/core/avatar/avatar_cache.dart';
import 'package:vikunja_mobile/core/avatar/avatar_providers.dart';
import 'package:vikunja_mobile/core/db/account_database_files.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/notification_fakes.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';
import '../../helpers/task_details_fakes.dart';

/// Can hold the wipe where it deletes the database, after the account's
/// memory caches went and before its images do.
final class _HeldDatabaseFiles implements AccountDatabaseFiles {
  Future<void> Function()? beforeDelete;

  @override
  Future<String> pathFor(String accountId) async =>
      '/support/accounts/$accountId/vikunja.db';

  @override
  Future<Directory> uploadsDirectoryFor(String accountId) async =>
      Directory('/support/accounts/$accountId/uploads');

  @override
  Future<void> deleteFor(String accountId) async {
    await beforeDelete?.call();
  }
}

void main() {
  const xl = AttachmentPreviewSize.extraLarge;
  final noon = DateTime.utc(2026, 10, 19, 12);
  late Directory root;
  late AuthFakes auth;
  late ProviderContainer container;
  late Map<String, FakeSyncClient> readClients;
  late _HeldDatabaseFiles files;
  late AvatarFetch avatarFetch;
  late RegisteredAccount alice;
  late RegisteredAccount bob;

  Directory folderOf(RegisteredAccount account) =>
      Directory(p.join(root.path, account.id));

  List<String> filesOf(RegisteredAccount account) =>
      [for (final file in folderOf(account).listSync()) p.basename(file.path)]
        ..sort();

  Future<void> showPreview(RegisteredAccount account, int taskId) async {
    final client =
        container.read(readClientProvider(account.id)) as FakeSyncClient;
    client.attachmentBlobs[(taskId, 2, xl)] = AttachmentBlob(
      bytes: samplePngBytes,
      contentType: 'image/png',
    );
    await container
        .read(accountAttachmentImagesProvider(account.id))
        .load(taskId, 2, preview: xl);
    await container.read(accountImageDiskCacheProvider(account.id)).flush();
  }

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(
      () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
    );
    root = Directory.systemTemp.createTempSync('image_disk_cache_providers');
    addTearDown(() => root.deleteSync(recursive: true));
    auth = AuthFakes()..imageCacheRoot = () async => root;
    readClients = {};
    files = _HeldDatabaseFiles();
    avatarFetch = (_, _) async =>
        throw const NetworkFailure(NetworkProblem.unreachable);
    container = ProviderContainer(
      overrides: [
        ...auth.overrides,
        accountDatabaseFilesProvider.overrideWithValue(files),
        // The real one, with an avatar port the fake read client lacks.
        accountAvatarCacheProvider.overrideWith((ref, accountId) {
          final cache = AvatarCache(
            (username, size) => avatarFetch(username, size),
            disk: ref.watch(accountImageDiskCacheProvider(accountId)),
          );
          ref.onDispose(cache.dispose);
          return cache;
        }),
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
    alice = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: noon),
    );
    bob = await auth.seedAccount(
      oauthServer230(),
      tokens: issueTokens(issuedAt: noon, userId: 8, username: 'bob'),
      activate: false,
    );
    await container.read(accountsProvider.future);
  });

  test('each account keeps its images in a folder of its own, and signing '
      "out leaves nothing of the account's, the other's untouched", () async {
    await showPreview(alice, 4);
    await container
        .read(accountImageDiskCacheProvider(alice.id))
        .write('avatar-ab-32', samplePngImage);
    await showPreview(bob, 5);
    expect(filesOf(alice), ['attachment-4-2-xl', 'avatar-ab-32']);
    expect(filesOf(bob), ['attachment-5-2-xl']);

    await container.read(signOutProvider).call(alice.id);

    expect(folderOf(alice).existsSync(), isFalse);
    expect(root.listSync().map((entry) => p.basename(entry.path)), [bob.id]);
    expect(filesOf(bob), ['attachment-5-2-xl']);
    expect(
      await container.read(accountRegistryProvider).accountsToDelete(),
      isEmpty,
    );
  });

  test(
    'a preview that arrives while the account signs out is not kept',
    () async {
      final answer = Completer<void>();
      final client =
          container.read(readClientProvider(alice.id)) as FakeSyncClient
            ..beforeRequest = ((_) => answer.future);
      client.attachmentBlobs[(4, 2, xl)] = AttachmentBlob(
        bytes: samplePngBytes,
        contentType: 'image/png',
      );
      final disk = container.read(accountImageDiskCacheProvider(alice.id));
      final loading = container
          .read(accountAttachmentImagesProvider(alice.id))
          .load(4, 2, preview: xl);

      await container.read(signOutProvider).call(alice.id);
      answer.complete();
      await loading;
      await disk.flush();

      expect(client.requests, ['attachment 4 2 xl']);
      expect(folderOf(alice).existsSync(), isFalse);
    },
  );

  test('a folder that cannot be deleted leaves the account to the wipe at '
      'the next start', () async {
    await showPreview(alice, 4);
    auth.imageCacheRoot = () async =>
        throw const FileSystemException('cache folder unavailable');

    await container.read(signOutProvider).call(alice.id);

    expect(await container.read(accountRegistryProvider).accountsToDelete(), [
      alice.id,
    ]);
    expect(filesOf(alice), ['attachment-4-2-xl']);

    auth.imageCacheRoot = () async => root;
    expect(await container.read(accountDeletionsProvider).finishAll(), isTrue);

    expect(folderOf(alice).existsSync(), isFalse);
    expect(
      await container.read(accountRegistryProvider).accountsToDelete(),
      isEmpty,
    );
  });

  test('after a folder that could not be deleted, the account signed in '
      'again in the same session keeps its images again', () async {
    await showPreview(alice, 4);
    final closed = container.read(accountImageDiskCacheProvider(alice.id));
    auth.imageCacheRoot = () async =>
        throw const FileSystemException('cache folder unavailable');
    await container.read(signOutProvider).call(alice.id);
    auth.imageCacheRoot = () async => root;

    final again = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: noon),
    );
    await showPreview(again, 6);

    expect(again.id, alice.id);
    expect(filesOf(alice), ['attachment-4-2-xl', 'attachment-6-2-xl']);
    expect(
      container.read(accountImageDiskCacheProvider(alice.id)),
      isNot(same(closed)),
    );
  });

  test('the wipe at the next start deletes the folder of an account whose '
      'disk cache this session never made', () async {
    await ImageDiskCache.forAccount(
      () async => root,
      alice.id,
    ).write('attachment-4-2-xl', samplePngImage);
    await container.read(accountRegistryProvider).remove(alice.id);
    expect(container.exists(accountImageDiskCacheProvider(alice.id)), isFalse);

    // Not finishAll: its sweep of unknown folders would hide a wipe that
    // leaves the images.
    expect(
      await container.read(accountDeletionsProvider).finish(alice.id),
      isTrue,
    );

    expect(folderOf(alice).existsSync(), isFalse);
  });

  test('answers that arrive during the wipe, once the memory caches went '
      'and before the images go, leave nothing behind', () async {
    final avatar = Completer<AvatarImage>();
    avatarFetch = (_, _) => avatar.future;
    final preview = Completer<void>();
    final client =
        container.read(readClientProvider(alice.id)) as FakeSyncClient
          ..beforeRequest = ((_) => preview.future);
    client.attachmentBlobs[(4, 2, xl)] = AttachmentBlob(
      bytes: samplePngBytes,
      contentType: 'image/png',
    );
    final disk = container.read(accountImageDiskCacheProvider(alice.id));
    final avatarLoad = container
        .read(accountAvatarCacheProvider(alice.id))
        .load('alice', 32);
    final previewLoad = container
        .read(accountAttachmentImagesProvider(alice.id))
        .load(4, 2, preview: xl);
    final wiping = Completer<void>();
    final release = Completer<void>();
    files.beforeDelete = () {
      wiping.complete();
      return release.future;
    };

    final signingOut = container.read(signOutProvider).call(alice.id);
    await wiping.future;
    avatar.complete(
      AvatarImage(bytes: samplePngBytes, contentType: 'image/png'),
    );
    preview.complete();
    await avatarLoad;
    await previewLoad;
    await disk.flush();
    expect(filesOf(alice), [
      startsWith('avatar-'),
    ], reason: 'the avatar cache, gone from memory, still wrote');
    release.complete();
    await signingOut;

    expect(folderOf(alice).existsSync(), isFalse);
  });

  test('the start deletes the image folders of accounts the registry does '
      'not know', () async {
    await showPreview(alice, 4);
    await showPreview(bob, 5);
    File(p.join(root.path, 'gone', 'attachment-1-2-xl'))
        .createSync(recursive: true);

    expect(await container.read(accountDeletionsProvider).finishAll(), isTrue);

    expect(
      root.listSync().map((entry) => p.basename(entry.path)),
      unorderedEquals([alice.id, bob.id]),
    );
  });
}
