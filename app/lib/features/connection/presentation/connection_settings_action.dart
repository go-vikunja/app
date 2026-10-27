import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/network/network_profile_providers.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/features/connection/application/connection_fix.dart';
import 'package:vikunja_mobile/features/connection/presentation/connection_navigation.dart';

/// For a failure that only [serverRoot]'s connection settings fix, away
/// from the connect screen: the way to them, or for unreadable settings
/// their reset. [onChanged] runs once something changed, e.g. a retry.
class ConnectionSettingsAction extends ConsumerWidget {
  const new({
    required this.error,
    required this.serverRoot,
    this.onChanged,
    this.foreground,
    super.key,
  });

  final Object? error;
  final Uri serverRoot;
  final VoidCallback? onChanged;
  final Color? foreground;

  static bool appliesTo(Object? error) =>
      opensConnectionSettings(error) || needsConnectionSettingsReset(error);

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final origin = OriginKey.tryOf(serverRoot);
    if (origin == null) return;
    if (await openConnectionSettings(context, ref, origin)) onChanged?.call();
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final profiles = ref.read(networkProfilesProvider);
    if (await resetConnectionSettings(context, profiles)) onChanged?.call();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (!appliesTo(error) || OriginKey.tryOf(serverRoot) == null) {
      return const SizedBox.shrink();
    }
    final reset = needsConnectionSettingsReset(error);
    return TextButton.icon(
      onPressed: () =>
          unawaited(reset ? _reset(context, ref) : _open(context, ref)),
      style: TextButton.styleFrom(foregroundColor: foreground),
      icon: Icon(reset ? Icons.restart_alt : Icons.tune),
      label: Text(reset ? l10n.connectionReset : l10n.connectionOpenSettings),
    );
  }
}
