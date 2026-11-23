import 'dart:async';

import 'package:drift/drift.dart';

extension WatchTables on DatabaseConnectionUser {
  /// Runs [load] once per subscriber and again after every change to one of
  /// [tables] and every event of [alsoOn], like drift's own `watch()` does
  /// for a single query. Changes that arrive while a load runs are folded
  /// into one reload, so the subscriber only ever sees the newest state.
  /// While the subscriber is paused nothing loads: the resume loads once if
  /// something changed, else delivers what a load running at the pause
  /// found.
  Stream<T> watchTables<T>(
    Iterable<ResultSetImplementation<dynamic, dynamic>> tables,
    Future<T> Function() load, {
    Stream<void>? alsoOn,
  }) => Stream.multi((subscriber) {
    var dirty = true;
    var loading = false;
    var paused = false;
    var cancelled = false;
    void Function()? held;

    Future<void> reload() async {
      if (loading) return;
      loading = true;
      while (dirty && !paused && !cancelled) {
        dirty = false;
        void Function() deliver;
        try {
          final value = await load();
          deliver = () => subscriber.add(value);
        } on Object catch (error, stackTrace) {
          deliver = () => subscriber.addError(error, stackTrace);
        }
        if (cancelled) break;
        if (paused) {
          held = deliver;
        } else {
          deliver();
        }
      }
      loading = false;
    }

    void markDirty(Object? _) {
      dirty = true;
      unawaited(reload());
    }

    // Kept listening while paused: they only mark the state stale, and a
    // paused subscription would queue their events instead.
    final updates = tableUpdates(TableUpdateQuery.onAllTables(tables))
        .listen(markDirty);
    final extra = alsoOn?.listen(markDirty);
    subscriber
      ..onPause = () {
        paused = true;
      }
      ..onResume = () {
        paused = false;
        final kept = held;
        held = null;
        if (dirty) {
          unawaited(reload());
        } else {
          kept?.call();
        }
      }
      ..onCancel = () async {
        cancelled = true;
        held = null;
        await Future.wait([updates.cancel(), ?extra?.cancel()]);
      };
    unawaited(reload());
  });
}
