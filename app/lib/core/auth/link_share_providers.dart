import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/link_share_gateway.dart';
import 'package:vikunja_mobile/core/auth/link_share_session.dart';
import 'package:vikunja_mobile/core/auth/link_share_store.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';

part 'link_share_providers.g.dart';

@Riverpod(keepAlive: true)
LinkShareStore linkShareStore(Ref ref) =>
    LinkShareStore(ref.watch(secureStoreProvider));

@Riverpod(keepAlive: true)
LinkShareGateway linkShareGateway(Ref ref) =>
    ApiLinkShareGateway(ref.watch(authDioProvider));

/// A container the OS started without the app authenticates a guest again
/// at most once: the background job runs every half hour, and the shared
/// sign-in limit must not be spent on a password the user has to type.
@Riverpod(keepAlive: true)
LinkShareSessions linkShareSessions(Ref ref) {
  final registry = ref.watch(accountRegistryProvider);
  return LinkShareSessions(
    store: ref.watch(linkShareStoreProvider),
    gateway: ref.watch(linkShareGatewayProvider),
    connectionFor: (accountId) async =>
        (await registry.find(accountId))?.connection,
    markNeedsReauth: registry.markNeedsReauth,
    maxAuthentications: ref.watch(runsHeadlessProvider) ? 1 : null,
  );
}
