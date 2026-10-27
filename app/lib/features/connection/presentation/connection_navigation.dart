import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/router/pushed_pages.dart';
import 'package:vikunja_mobile/core/network/network_profile_providers.dart';
import 'package:vikunja_mobile/core/network/network_profiles.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/features/tasks/presentation/confirm_dialog.dart';

final _log = Logger('ConnectionSettings');

/// The editors the connection screen opens itself, and that a failure's
/// action opens directly.
enum ConnectionEditor { certificate, headers, clientCertificate }

/// Opens [origin]'s connection screen, or one of its [editor]s, and says
/// once it closed whether the settings changed in a way worth a retry.
Future<bool> openConnectionSettings(
  BuildContext context,
  WidgetRef ref,
  OriginKey origin, {
  ConnectionEditor? editor,
}) async {
  final profiles = ref.read(networkProfilesProvider);
  final before = await profiles.stateFor(origin);
  if (!context.mounted) return false;
  await context.pushPage<void>(AppRoutes.connectionFor(origin, editor: editor));
  return worthRetrying(before, await profiles.stateFor(origin));
}

/// Every edit bumps the revision; a reset or storage that became readable
/// changes the status. Keeping the trusted certificate after a change only
/// dismisses the notice, and the server would refuse again.
bool worthRetrying(
  ConnectionProfileState before,
  ConnectionProfileState after,
) {
  if (before.profile?.revision != after.profile?.revision) return true;
  return before.status != after.status &&
      !(before.status == ConnectionProfileStatus.pinMismatch &&
          after.status == ConnectionProfileStatus.ok);
}

Future<bool> confirmConnectionSettingsReset(BuildContext context) {
  final l10n = context.l10n;
  return confirmAdaptive(
    context,
    title: l10n.connectionResetTitle,
    body: l10n.connectionResetBody,
    confirmLabel: l10n.connectionResetConfirm,
    destructive: true,
  );
}

/// Asks first; true once every server's settings were reset.
Future<bool> resetConnectionSettings(
  BuildContext context,
  NetworkProfiles profiles,
) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  if (!await confirmConnectionSettingsReset(context)) return false;
  try {
    await profiles.resetAll();
    return true;
  } on Object catch (error) {
    _log.warning(
      'Resetting the connection settings failed: ${error.runtimeType}',
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.connectionSaveFailed)));
    return false;
  }
}
