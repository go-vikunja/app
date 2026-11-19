import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/sync/sync_providers.dart';
import 'package:vikunja_mobile/features/sync/application/sync_status_queries.dart';

part 'quiet_sync_indicator.g.dart';

/// Whether the quiet indicator under the app bars shows: once a sync after
/// the first has run for [showAfter], until it ends. One state for every
/// screen, so a screen opened during a long run shows it at once.
@Riverpod(keepAlive: true)
class QuietSyncIndicator extends _$QuietSyncIndicator {
  /// Most runs of the foreground timer end sooner, and a bar flashing every
  /// minute only distracts. A refresh the user starts shows its own
  /// progress (the pull's spinner, the Refresh item turned off, Sync now's
  /// spinner).
  static const showAfter = Duration(seconds: 1);

  @override
  bool build() {
    final syncing = ref.watch(
      syncStatusProvider.select((status) => isSyncingQuietly(status.value)),
    );
    if (!syncing) return false;
    final delay = Timer(showAfter, () => state = true);
    ref.onDispose(delay.cancel);
    return false;
  }
}
