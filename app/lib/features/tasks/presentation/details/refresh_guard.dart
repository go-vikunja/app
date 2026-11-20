import 'dart:async';

/// The rule a details controller keeps for its quiet refreshes: one under
/// way when a change is made here may have read the server before it, so
/// it is dropped and run again once [writing] has nothing pending.
///
/// [generation] counts the controller's reads, its loads included: a read
/// that answers for an older one is stale. [refreshing] is the generation
/// of the refresh under way, if any.
final class RefreshGuard {
  new(this._refresh);

  final Future<void> Function() _refresh;
  int generation = 0;
  int? refreshing;
  int _writes = 0;
  bool _due = false;
  bool _disposed = false;

  bool get hasWrites => _writes > 0;
  bool get disposed => _disposed;

  /// Asks for a refresh once [writing] has nothing pending.
  void markDue() => _due = true;

  /// Runs [write], which changes on the server what a change made here
  /// already shows: refreshes wait until it is done.
  Future<T> writing<T>(Future<T> Function() write) async {
    _writes++;
    drop();
    try {
      return await write();
    } finally {
      _writes--;
      refreshIfDue();
    }
  }

  /// Drops the refresh under way, if it is the latest read, and asks for
  /// another.
  void drop() {
    if (refreshing == null || refreshing != generation) return;
    refreshing = null;
    generation++;
    _due = true;
    refreshIfDue();
  }

  void refreshIfDue() {
    if (_writes > 0 || !_due || _disposed) return;
    _due = false;
    unawaited(_refresh());
  }

  void dispose() => _disposed = true;
}
