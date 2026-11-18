import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/link_share_providers.dart';
import 'package:vikunja_mobile/core/auth/sign_out.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';

part 'sign_out_providers.g.dart';

// Apart from auth_providers.dart because sign-out wipes the account's
// database, whose providers build on the auth providers.
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
