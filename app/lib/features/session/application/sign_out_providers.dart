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
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
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
/// reminder included, and in the tray) and forgets their preferences, the
/// background notes, the last session end, the sign-in page on another
/// host it confirmed, that it was kept as an http account, the unsent
/// comments and the description draft, replaces its home-screen widgets'
/// content with "Account removed", stops its outbox sender and sync engine,
/// closes its database and deletes the files: the database, the stored
/// copies of queued uploads, the downloaded attachments and the images
/// kept on disk.
@Riverpod(keepAlive: true)
AccountDataWiper accountDataWiper(Ref ref) => (accountId) async {
  BackgroundRunnerChannel.release(accountId);
  ref
    ..invalidate(accountAvatarCacheProvider(accountId))
    ..invalidate(accountAttachmentImagesProvider(accountId));
  await _disposeQuietly('Background notes', accountId, () async {
    await ref.read(backgroundRunLogProvider).forget(accountId);
    await ref.read(sessionEndLogProvider).forget(accountId);
    await ref.read(sessionDiagnosticsProvider).forget(accountId);
    await ref
        .read(preferencesStoreProvider)
        .remove(ActivityNotifier.sessionEndedKey(accountId));
  });
  await _disposeQuietly(
    'Confirmed sign-in host',
    accountId,
    () =>
        ConfirmedSignInHosts(ref.read(preferencesStoreProvider))
            .forget(accountId),
  );
  await _disposeQuietly(
    'Kept http account',
    accountId,
    () => KeptHttpTwins(ref.read(preferencesStoreProvider)).forget(accountId),
  );
  await _disposeQuietly(
    'Comment drafts',
    accountId,
    () => ref.read(commentDraftsProvider).discardAll(accountId),
  );
  await _disposeQuietly(
    'Description draft',
    accountId,
    () => ref.read(descriptionDraftsProvider).discardAll(accountId),
  );
  await _disposeQuietly(
    'Notification scheduler',
    accountId,
    () => ref.read(notificationSchedulersProvider).cancelAll(accountId),
  );
  await _disposeQuietly(
    'Session reminder',
    accountId,
    () => ref.read(sessionRemindersProvider).cancel(accountId),
  );
  await _disposeQuietly(
    'Delivered notifications',
    accountId,
    () =>
        ActivityTray(ref.read(notificationGatewayProvider))
            .withdrawAll(accountId),
  );
  await _disposeQuietly(
    'Notification preferences',
    accountId,
    () => ref.read(notificationPreferencesStoreProvider).delete(accountId),
  );
  await _disposeQuietly(
    'Widgets',
    accountId,
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
  await ref.read(openDatabasesProvider).closeForDeletion(accountId);
  await ref.read(accountDatabaseFilesProvider).deleteFor(accountId);
  ref.invalidate(accountUploadFilesProvider(accountId));
  await _disposeQuietly(
    'Downloaded attachments',
    accountId,
    () => ref.read(attachmentDownloadsProvider).purgeAccount(accountId),
  );
  // Not quietly: unlike the downloads, which go after a few days unused,
  // nothing else deletes the images of an account still listed to delete,
  // so a failure leaves the account to the next start's wipe. The closed
  // instance goes either way: a sign-in again would find it closed.
  try {
    await ref.read(accountImageDiskCacheProvider(accountId)).deleteAll();
  } finally {
    ref.invalidate(accountImageDiskCacheProvider(accountId));
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
);
