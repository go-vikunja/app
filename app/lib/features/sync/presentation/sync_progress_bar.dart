import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/sync/sync_providers.dart';
import 'package:vikunja_mobile/features/sync/application/sync_status_queries.dart';

/// The quiet indicator under an app bar while a sync after the first one
/// runs. Takes its height even when idle, so the content never jumps.
class SyncProgressBar extends ConsumerWidget implements PreferredSizeWidget {
  const new({super.key});

  static const height = 4.0;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncing = ref.watch(
      syncStatusProvider.select((status) => isSyncingQuietly(status.value)),
    );
    if (!syncing) return const SizedBox(height: height);
    return LinearProgressIndicator(
      minHeight: height,
      semanticsLabel: context.l10n.syncIndicatorLabel,
    );
  }
}
