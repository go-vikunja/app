import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/outbox/external_done.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/core/widgets/widget_host.dart';
import 'package:vikunja_mobile/core/widgets/widget_providers.dart';

final _log = Logger('WidgetTaps');

/// Applies widget Done taps exactly once: each one's Done is queued in the
/// outbox and its id recorded in one transaction of its account's
/// database, so a tap read again after a crash between that commit and
/// the deletion of its file is skipped. A tap of an account that is not
/// signed in (any more) is dropped. Then [ExternalDone.settle] runs per
/// account: notifications, widgets, the drain and the plan.
final class WidgetTapImport {
  new(this._container, {required this._done, this.drains = true});

  /// How long an applied tap's id is kept, far beyond the life of a file
  /// that failed to be deleted.
  static const keepImported = Duration(days: 30);

  final ProviderContainer _container;
  final ExternalDone _done;

  /// Whether [ExternalDone.settle] drains the outbox.
  final bool drains;

  /// The ids of the taps that are settled: applied now or before, or
  /// dropped. A tap whose write failed is not among them, so it is tried
  /// again.
  Future<Set<String>> apply(Iterable<WidgetDoneTap> taps) async {
    if (taps.isEmpty) return const {};
    final accounts = await _container.read(accountsProvider.future);
    final now = _container.read(clockProvider);
    final settled = <String>{};
    final byAccount = <String, List<WidgetDoneTap>>{};
    for (final tap in taps) {
      byAccount.putIfAbsent(tap.accountId, () => []).add(tap);
    }
    for (final MapEntry(key: accountId, value: accountTaps)
        in byAccount.entries) {
      if (accounts.find(accountId) == null) {
        _log.info(
          'Dropped ${accountTaps.length} widget taps of an unknown account',
        );
        settled.addAll(accountTaps.map((tap) => tap.id));
        continue;
      }
      final db = _container.read(appDatabaseProvider(accountId));
      final done = <int>{};
      for (final tap in accountTaps) {
        try {
          final queued = await db.transaction(() async {
            if (await db.importedWidgetActionsDao.contains(tap.id)) {
              return false;
            }
            final queued = await db.outboxDao.queueUpdate(
              tap.taskId,
              const TaskChanges(done: true),
              now: now(),
            );
            await db.importedWidgetActionsDao.add(tap.id, at: now());
            return queued;
          });
          settled.add(tap.id);
          if (queued) done.add(tap.taskId);
        } on Object catch (error) {
          _log.warning('Could not apply a widget tap: ${error.runtimeType}');
        }
      }
      try {
        await db.importedWidgetActionsDao.forgetBefore(
          now().subtract(keepImported),
        );
        if (done.isNotEmpty) {
          await _done.settle(accountId, done, drains: drains);
        }
      } on Object catch (error) {
        _log.warning(
          'Could not settle the widget taps of account $accountId: '
          '${error.runtimeType}',
        );
      }
    }
    return settled;
  }
}

/// Takes the widget Done taps waiting for the app (Android's queue, the
/// iOS outbox), applies them and acknowledges the settled ones, which
/// deletes them only after their Done is committed, then redraws the
/// widgets: they hide a row while its tap is waiting, so a redraw before
/// the acknowledgement would keep it hidden. Never throws.
Future<void> importWidgetTaps(
  ProviderContainer container, {
  Duration drainTimeout = const Duration(seconds: 20),
  bool drains = true,
}) async {
  try {
    final host = container.read(widgetHostProvider);
    final taps = await host.takeActions();
    if (taps.isEmpty) return;
    final settled = await WidgetTapImport(
      container,
      done: ExternalDone(container, drainTimeout: drainTimeout),
      drains: drains,
    ).apply(taps);
    if (settled.isNotEmpty) {
      await host.ackActions(settled);
      await host.updateAll();
    }
    _log.fine('Imported ${settled.length} of ${taps.length} widget taps');
  } on Object catch (error) {
    _log.warning('Could not import the widget taps: ${error.runtimeType}');
  }
}
