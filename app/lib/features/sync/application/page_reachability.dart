import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/sync/application/offline_state.dart';

/// Whether a page that reads the server itself is offline. The page's own
/// last request decides: a sync run that failed before it may be minutes
/// old, the scheduler backs off that far. A sync outcome that arrives later
/// decides again, and before the page's first answer the last sync run
/// does.
mixin PageReachability<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool? _reachable;

  /// What the page's last request found; null when the sync decides.
  bool? get reachable => _reachable;

  /// Inside `setState`, after a request of the page got an answer.
  void noteReached() => _reachable = true;

  /// Inside `setState`, after a request of the page failed with [error].
  void noteFailure(Object error) {
    if (error is NetworkFailure) _reachable = false;
  }

  /// For `build`. [onBackOnline] runs when a sync run gets through again
  /// after one that could not reach the server.
  bool watchOffline({VoidCallback? onBackOnline}) {
    ref.listen(offlineProvider, (previous, next) {
      if (mounted) setState(() => _reachable = null);
      if (previous != null && next == null) onBackOnline?.call();
    });
    final lastSyncOffline = ref.watch(offlineProvider) != null;
    return switch (_reachable) {
      null => lastSyncOffline,
      final reachable => !reachable,
    };
  }
}
