import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/network/network_profile_providers.dart';
import 'package:vikunja_mobile/core/network/network_profiles.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/features/connection/presentation/connection_navigation.dart';
import 'package:vikunja_mobile/features/connection/presentation/connection_texts.dart';

/// The Account tab's way to the active account's server address settings,
/// for users and guests alike: what is stored, or what needs the user.
class ConnectionTile extends ConsumerWidget {
  const new({required this.serverRoot, this.enabled = true, super.key});

  final Uri serverRoot;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final origin = OriginKey.tryOf(serverRoot);
    if (origin == null) return const SizedBox.shrink();
    final state = ref.watch(connectionProfileProvider(origin)).value;
    final subtitle = state == null ? null : connectionStatusText(l10n, state);
    final attention = switch (state?.status) {
      null || ConnectionProfileStatus.ok => false,
      _ => true,
    };
    return ListTile(
      leading: Icon(
        attention ? Icons.gpp_maybe_outlined : Icons.security_outlined,
        color: attention ? theme.colorScheme.error : null,
      ),
      title: Text(l10n.connectionTitle),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      enabled: enabled,
      onTap: () => unawaited(openConnectionSettings(context, ref, origin)),
    );
  }
}
