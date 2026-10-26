import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';

part 'access_cleanup.g.dart';

/// Whether [connection]'s server, from 2.7.0, also deletes the task
/// assignments, subscriptions and webhooks of whoever loses access to a
/// project; the confirmations then list them, as the web's do.
bool serverCleansUpAccess(ServerConnection? connection) =>
    connection?.info.version?.isAtLeast(2, 7) ?? false;

/// [serverCleansUpAccess] for the active account's server.
@riverpod
bool activeServerCleansUpAccess(Ref ref) => ref.watch(
  accountsProvider.select(
    (accounts) =>
        serverCleansUpAccess(accounts.value?.activeAccount?.connection),
  ),
);
