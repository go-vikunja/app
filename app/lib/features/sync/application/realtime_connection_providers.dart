import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/network/network_profile_providers.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/core/realtime/realtime_connection.dart';
import 'package:vikunja_mobile/core/realtime/realtime_providers.dart';
import 'package:vikunja_mobile/core/repositories/activity_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_providers.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/session/application/sign_out_controller.dart';
import 'package:vikunja_mobile/features/sync/application/offline_state.dart';
import 'package:vikunja_mobile/features/sync/application/sync_status_queries.dart';

part 'realtime_connection_providers.g.dart';

/// The active account's socket, gated and driven like the foreground sync
/// scheduler: replaced on an account switch; gone in a background
/// container, while nobody is signed in, before the account's first sync,
/// while its session needs a new sign-in, during a sign-out and on a server
/// without websockets, for a link-share guest, and until the server's
/// connection settings were read; replaced when they are edited; closed
/// while the app is not in front or nothing listens (the shell does).
@Riverpod(keepAlive: true)
RealtimeConnection? realtimeConnection(Ref ref) {
  if (ref.watch(runsHeadlessProvider)) return null;
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return null;
  final needsReauth = ref.watch(
    accountsProvider.select(
      (accounts) => accounts.value?.find(accountId)?.account.needsReauth,
    ),
  );
  if (needsReauth ?? true) return null;
  // The server's socket takes user tokens only.
  if (ref.watch(accountIsGuestProvider(accountId))) return null;
  // The change disposes the connection at once, before the logout request:
  // the server closes the session's sockets when the logout ends the
  // session, and that close must not reach the session manager.
  if (ref.watch(signOutControllerProvider)) return null;
  final url = ref.watch(
    accountsProvider.select(
      (accounts) => _realtimeUrl(accounts.value?.find(accountId)?.connection),
    ),
  );
  if (url == null) return null;
  // A recorded certificate mismatch changes nothing here.
  if (ref.watch(connectionProfileRevisionProvider(OriginKey.of(url))) == null) {
    return null;
  }
  final firstSyncPending = ref.watch(
    accountSyncStatusProvider(accountId)
        .select((status) => needsFirstSync(status.value)),
  );
  if (firstSyncPending) return null;

  final connection = RealtimeConnection(
    connector: ref.watch(realtimeConnectorProvider),
    url: url,
    tokens: AccountTokens(ref.watch(sessionManagersProvider), accountId),
    engine: ref.watch(syncEngineProvider(accountId)),
    activity: ref.watch(accountActivityRepositoryProvider(accountId)),
    clock: ref.watch(clockProvider),
  );
  var listened = true;
  bool inFront() => switch (WidgetsBinding.instance.lifecycleState) {
    null || AppLifecycleState.resumed || AppLifecycleState.inactive => true,
    _ => false,
  };
  final lifecycle = AppLifecycleListener(
    onResume: () {
      if (listened) connection.onResume();
    },
    onHide: connection.onPause,
    onPause: connection.onPause,
  );
  ref
    ..listen(
      offlineProvider,
      (_, offline) => connection.setOffline(offline: offline != null),
      fireImmediately: true,
    )
    ..onDispose(() {
      lifecycle.dispose();
      connection.dispose();
    })
    ..onCancel(() {
      listened = false;
      connection.onPause();
    })
    ..onResume(() {
      listened = true;
      if (inFront()) connection.start();
    });
  if (inFront()) connection.start();
  return connection;
}

Uri? _realtimeUrl(ServerConnection? connection) {
  if (connection == null ||
      !connection.capabilities.has(Capability.websocket)) {
    return null;
  }
  return realtimeUri(connection);
}
