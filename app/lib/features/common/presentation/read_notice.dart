import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/core/auth/failed_without_token.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_card.dart';
import 'package:vikunja_mobile/features/sync/presentation/offline_notice.dart';

/// The notice above what a page read from the server: the offline notice
/// after an outage, or while [offline] with no failure of its own, and none
/// without [showsOffline] (under the shell's banner). Any other failure, a
/// connection-settings one included, is explained over the stale data.
/// Null without data for a failure that is no outage, so the page shows its
/// card in the data's place (decision log: Connections).
Widget? readNotice(
  Object? failure, {
  required bool hasData,
  required VoidCallback onRetry,
  bool offline = false,
  bool showsOffline = true,
  Widget Function(Object failure)? staleCard,
}) => switch (failure) {
  _ when failedAsOutage(failure) || (failure == null && offline) =>
    showsOffline ? const OfflineNotice() : null,
  final error? when hasData =>
    staleCard?.call(error) ??
        DataFailureCard(error: error, stale: true, onRetry: onRetry),
  _ => null,
};
