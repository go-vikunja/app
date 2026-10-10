import 'dart:async';

import 'package:drift/drift.dart';

extension WatchTables on DatabaseConnectionUser {
  /// Runs [load] once per subscriber and again after every change to one of
  /// [tables], like drift's own `watch()` does for a single query. Changes
  /// that arrive while a load runs are folded into one reload, so the
  /// subscriber only ever sees the newest state.
  Stream<T> watchTables<T>(
    Iterable<ResultSetImplementation<dynamic, dynamic>> tables,
    Future<T> Function() load,
  ) => Stream.multi((subscriber) {
    var dirty = true;
    var loading = false;
    var cancelled = false;

    Future<void> reload() async {
      if (loading) return;
      loading = true;
      while (dirty && !cancelled) {
        dirty = false;
        try {
          final value = await load();
          if (!cancelled) subscriber.add(value);
        } on Object catch (error, stackTrace) {
          if (!cancelled) subscriber.addError(error, stackTrace);
        }
      }
      loading = false;
    }

    final updates = tableUpdates(TableUpdateQuery.onAllTables(tables))
        .listen((_) {
          dirty = true;
          unawaited(reload());
        });
    subscriber.onCancel = () {
      cancelled = true;
      return updates.cancel();
    };
    unawaited(reload());
  });
}
