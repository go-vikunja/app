import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/network/network_profile_providers.dart';
import 'package:vikunja_mobile/core/network/network_profiles.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/features/connection/application/connection_fix.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connection_error_card.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/failure_message.dart';

typedef ConnectionFixHandler = void Function(
  ConnectionFix fix,
  OriginKey origin,
);

/// A failure on the connect screen with the way to what fixes it in the
/// failed [origin]'s connection settings, worded by what they hold.
class ConnectFailureCard extends ConsumerWidget {
  const new({
    required this.error,
    required this.origin,
    required this.describe,
    required this.onFix,
    super.key,
  });

  final Object? error;
  final OriginKey? origin;

  /// Gets the failed origin's settings, null while they are unknown.
  final FailureMessage Function(ConnectionProfileState? settings) describe;
  final ConnectionFixHandler onFix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final origin = this.origin;
    final fix = connectionFixFor(error);
    final settings = origin == null || fix == null
        ? null
        : ref.watch(connectionProfileProvider(origin)).value;
    final hasClientCertificate = settings?.profile?.clientCertificate != null;
    return ConnectionErrorCard(
      message: describe(settings),
      action: fix == null || origin == null
          ? null
          : TextButton(
              onPressed: () => onFix(fix, origin),
              style: TextButton.styleFrom(
                foregroundColor: colors.onErrorContainer,
              ),
              child: Text(
                connectionFixLabel(
                  l10n,
                  fix,
                  hasClientCertificate: hasClientCertificate,
                ),
              ),
            ),
    );
  }
}

String connectionFixLabel(
  AppLocalizations l10n,
  ConnectionFix fix, {
  bool hasClientCertificate = false,
}) => switch (fix) {
  ConnectionFix.viewCertificate => l10n.connectionViewCertificate,
  ConnectionFix.addHeaders => l10n.connectionAddHeaders,
  ConnectionFix.clientCertificate =>
    hasClientCertificate
        ? l10n.connectionReplaceClientCertificate
        : l10n.connectionAddClientCertificate,
  ConnectionFix.openSettings => l10n.connectionOpenSettings,
  ConnectionFix.retry => l10n.retry,
  ConnectionFix.reset => l10n.connectionReset,
};
