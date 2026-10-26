import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';

part 'team_server_providers.g.dart';

/// Whether the active account's server had public teams turned on when the
/// account signed in; the app does not ask again while signed in.
@riverpod
bool activeServerHasPublicTeams(Ref ref) => ref.watch(
  accountsProvider.select(
    (accounts) =>
        accounts.value?.activeAccount?.connection.capabilities.has(
          Capability.publicTeams,
        ) ??
        false,
  ),
);
