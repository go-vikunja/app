import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/activity/activity_notifier.dart';
import 'package:vikunja_mobile/core/activity/activity_tray.dart';
import 'package:vikunja_mobile/core/attachments/attachment_image_providers.dart';
import 'package:vikunja_mobile/core/attachments/image_disk_cache.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/link_share_providers.dart';
import 'package:vikunja_mobile/core/auth/sign_out.dart';
import 'package:vikunja_mobile/core/avatar/avatar_providers.dart';
import 'package:vikunja_mobile/core/background/background_providers.dart';
import 'package:vikunja_mobile/core/background/background_runner_channel.dart';
import 'package:vikunja_mobile/core/files/file_actions_providers.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_actions.dart';
import 'package:vikunja_mobile/core/notifications/notification_providers.dart';
import 'package:vikunja_mobile/core/notifications/notification_schedulers.dart';
import 'package:vikunja_mobile/core/notifications/session_reminders.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/storage/comment_drafts.dart';
import 'package:vikunja_mobile/core/support/session_end_log.dart';
import 'package:vikunja_mobile/core/widgets/widget_providers.dart';
import 'package:vikunja_mobile/features/accounts/application/https_twins.dart';
import 'package:vikunja_mobile/features/description_editor/application/description_drafts.dart';
import 'package:vikunja_mobile/features/session/application/sign_in_hosts.dart';

part 'sign_out_providers.g.dart';

// Here, not in core, because the wipe reaches every store that keeps
// something of an account, those of features included.

final _log = Logger('AccountData');

/// The last step of a sign-out: makes a background run in another isolate
/// let go of the account, drops its avatars and attachment images from
/// memory, cancels the account's notifications (scheduled, the session
/// reminder included, whatever else the OS holds for it, and in the tray)
/// and forgets their preferences, the background notes, the last session
/// end, the sign-in page on another host it confirmed, that it was kept as
/// an http account, the unsent comments and the description draft, replaces
/// its home-screen widgets' content with "Account removed", stops its
/// outbox sender and sync engine, closes its database and deletes the
/// files: the database, the stored copies of queued uploads, the downloaded
/// attachments, the images kept on disk and, on Android, share_plus's copy
/// of the file shared last, whichever account it came from. Every part is
/// tried, also after one failed, and the first failure is thrown at the
/// end, so the account stays listed to delete and the next start tries
/// again (decision log: Accounts and sign-in).
@Riverpod(keepAlive: true)
AccountDataWiper accountDataWiper(Ref ref) => (accountId) async {
  (Object, StackTrace)? failed;
  Future<void> attempt(String what, Future<void> Function() remove) async {
    try {
      await remove();
    } on Object catch (error, stackTrace) {
      _log.warning(
        '$what of account $accountId was not removed: ${error.runtimeType}',
      );
      failed ??= (error, stackTrace);
    }
  }

  BackgroundRunnerChannel.release(accountId);
  ref
    ..invalidate(accountAvatarCacheProvider(accountId))
    ..invalidate(accountAttachmentImagesProvider(accountId));
  await attempt(
    'Background run log',
    () => ref.read(backgroundRunLogProvider).forget(accountId),
  );
  await attempt(
    'Session end log',
    () => ref.read(sessionEndLogProvider).forget(accountId),
  );
  await attempt(
    'Session diagnostics',
    () => ref.read(sessionDiagnosticsProvider).forget(accountId),
  );
  await attempt(
    'Session end notice',
    () => ref
        .read(preferencesStoreProvider)
        .remove(ActivityNotifier.sessionEndedKey(accountId)),
  );
  await attempt(
    'Confirmed sign-in host',
    () =>
        ConfirmedSignInHosts(ref.read(preferencesStoreProvider))
            .forget(accountId),
  );
  await attempt(
    'Kept http account',
    () => KeptHttpTwins(ref.read(preferencesStoreProvider)).forget(accountId),
  );
  await attempt(
    'Comment drafts',
    () => ref.read(commentDraftsProvider).discardAll(accountId),
  );
  await attempt(
    'Description draft',
    () => ref.read(descriptionDraftsProvider).discardAll(accountId),
  );
  await attempt(
    'Notification scheduler',
    () => ref.read(notificationSchedulersProvider).cancelAll(accountId),
  );
  await attempt(
    'Session reminder',
    () => ref.read(sessionRemindersProvider).cancel(accountId),
  );
  await attempt('Pending notifications', () async {
    // A later start has no scheduler and no table (gone with the database),
    // so only the payloads name what the OS still holds.
    final gateway = ref.read(notificationGatewayProvider);
    for (final MapEntry(key: osId, value: payload)
        in (await gateway.pendingIds()).entries) {
      if (NotificationPayload.tryParse(payload)?.accountId == accountId) {
        await gateway.cancel(osId);
      }
    }
  });
  await attempt(
    'Delivered notifications',
    () =>
        ActivityTray(ref.read(notificationGatewayProvider))
            .withdrawAll(accountId),
  );
  await attempt(
    'Notification preferences',
    () => ref.read(notificationPreferencesStoreProvider).delete(accountId),
  );
  await attempt(
    'Widgets',
    () => ref.read(widgetPublishersProvider).wipe(accountId),
  );
  if (ref.exists(outboxSenderProvider(accountId))) {
    await _disposeQuietly(
      'Outbox sender',
      accountId,
      () => ref.read(outboxSenderProvider(accountId)).dispose(),
    );
  }
  if (ref.exists(syncEngineProvider(accountId))) {
    await _disposeQuietly(
      'Sync engine',
      accountId,
      () => ref.read(syncEngineProvider(accountId)).dispose(),
    );
  }
  await attempt('Database', () async {
    await ref.read(openDatabasesProvider).closeForDeletion(accountId);
    await ref.read(accountDatabaseFilesProvider).deleteFor(accountId);
  });
  ref.invalidate(accountUploadFilesProvider(accountId));
  await attempt(
    'Downloaded attachments',
    () => ref.read(attachmentDownloadsProvider).purgeAccount(accountId),
  );
  await attempt('Images on disk', () async {
    // The closed instance goes either way: a sign-in again would find it
    // closed.
    try {
      await ref.read(accountImageDiskCacheProvider(accountId)).deleteAll();
    } finally {
      ref.invalidate(accountImageDiskCacheProvider(accountId));
    }
  });
  await attempt('Shared copy', () async {
    // Nothing else deletes it before the next share; it holds only the last
    // share's files, which may be another account's.
    final folder = await ref.read(shareCopiesFolderProvider)();
    if (folder.existsSync()) await folder.delete(recursive: true);
  });
  if (failed case (final error, final stackTrace)?) {
    Error.throwWithStackTrace(error, stackTrace);
  }
};

Future<void> _disposeQuietly(
  String what,
  String accountId,
  Future<void> Function() dispose,
) async {
  try {
    await dispose();
  } on Object catch (error) {
    // The registry change got there first: the provider disposed it and
    // now refuses the unregistered account.
    _log.fine(
      '$what of account $accountId was already disposed: '
      '${error.runtimeType}',
    );
  }
}

@Riverpod(keepAlive: true)
AccountDeletions accountDeletions(Ref ref) => AccountDeletions(
  registry: ref.watch(accountRegistryProvider),
  wipe: ref.watch(accountDataWiperProvider),
  cancelScheduled: (accountId) async {
    final gateway = ref.read(notificationGatewayProvider);
    final database = ref.read(openDatabasesProvider).open(accountId);
    for (final osId in await database.scheduledNotificationsDao.osIds()) {
      await gateway.cancel(osId);
    }
  },
  wipeUnknown: (knownAccountIds) async {
    final root = await ref.read(imageDiskCacheRootProvider)();
    await ImageDiskCache.deleteOtherAccounts(root, knownAccountIds);
  },
);

@Riverpod(keepAlive: true)
SignOut signOut(Ref ref) => SignOut(
  registry: ref.watch(accountRegistryProvider),
  tokenStore: ref.watch(tokenStoreProvider),
  linkShareStore: ref.watch(linkShareStoreProvider),
  clockOffsets: ref.watch(serverClockOffsetsProvider),
  sessions: ref.watch(sessionManagersProvider),
  linkShares: ref.watch(linkShareSessionsProvider),
  accountGateway: ref.watch(accountGatewayProvider),
  deletions: ref.watch(accountDeletionsProvider),
  diagnostics: ref.watch(sessionDiagnosticsProvider),
);
