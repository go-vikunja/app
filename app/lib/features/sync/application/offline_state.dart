import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/failed_without_token.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';

part 'offline_state.g.dart';

@immutable
final class OfflineState {
  const new({required this.lastSyncedAt});

  /// When a run of the account last got through; null if none ever did.
  final DateTime? lastSyncedAt;

  @override
  bool operator ==(Object other) =>
      other is OfflineState && other.lastSyncedAt == lastSyncedAt;

  @override
  int get hashCode => lastSyncedAt.hashCode;
}

/// Offline from a sync run of the active account that could not reach the
/// server until a run gets through; null while online. A run in progress
/// keeps the last outcome, so a retry does not take the banner away for
/// the length of the retry.
@Riverpod(keepAlive: true)
class Offline extends _$Offline {
  @override
  OfflineState? build() {
    ref
      ..watch(activeAccountIdProvider)
      ..listen(
        syncStatusProvider,
        (_, next) => state = offlineAfter(state, next.value),
      );
    return offlineAfter(null, ref.read(syncStatusProvider).value);
  }
}

OfflineState? offlineAfter(OfflineState? previous, SyncStatus? status) =>
    switch (status) {
      // Storage that refused to read says nothing about the network, so an
      // outage shown before stays; a deferred renewal got the server's
      // answer.
      SyncFailed(failure: NetworkFailure(cause: SecureStorageUnreadable())) =>
        previous,
      SyncFailed(:final failure, :final lastSyncedAt)
          when failedAsOutage(failure) =>
        OfflineState(lastSyncedAt: lastSyncedAt),
      SyncRunning() || null => previous,
      _ => null,
    };
