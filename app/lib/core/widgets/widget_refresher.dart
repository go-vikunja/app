import 'package:vikunja_mobile/core/widgets/widget_config.dart';
import 'package:vikunja_mobile/core/widgets/widget_snapshot.dart';

/// What the rest of the app asks of the widgets: write an account's
/// snapshots now (after a widget was configured, a Done, a sign-in) and
/// preview a config.
abstract interface class WidgetRefresher {
  /// Builds and writes the snapshots of [accountId]'s placed widgets and
  /// its catalog, then asks the OS to redraw what changed. Never throws.
  Future<void> refresh(String accountId);

  /// [refresh] for every signed-in account.
  Future<void> refreshAll();

  /// [refresh] that also writes the snapshot of [config], though no widget
  /// shows it yet (one about to be placed), and redraws the widgets showing
  /// it even when it did not change (one just set up). Never throws.
  Future<void> publish(WidgetConfig config);

  /// What a widget with [config] would show now; nothing is written. Null
  /// when the account is not signed in.
  Future<WidgetSnapshot?> preview(WidgetConfig config);
}
