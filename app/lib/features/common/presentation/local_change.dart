import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

final _log = Logger('LocalChange');

/// Runs [write], which fails only when this device cannot store the change
/// (a full disk, an I/O error). When it fails, logs the error's type under
/// [action], says so on [messenger], else on the one of [context], and
/// returns false: confirm the change only after true.
///
/// The messenger is looked up before [write] starts, so the message still
/// shows when the screen has gone meanwhile.
Future<bool> saveLocalChange(
  BuildContext context,
  Future<void> Function() write, {
  required String action,
  ScaffoldMessengerState? messenger,
}) => saveLocalChangeIn(
  messenger ?? ScaffoldMessenger.maybeOf(context),
  context.l10n,
  write,
  action: action,
);

/// [saveLocalChange] without a context, e.g. for an Undo that may run after
/// its screen has gone: a [messenger] that has gone too says nothing.
Future<bool> saveLocalChangeIn(
  ScaffoldMessengerState? messenger,
  AppLocalizations l10n,
  Future<void> Function() write, {
  required String action,
}) async {
  try {
    await write();
    return true;
  } on Object catch (error) {
    _log.warning('$action failed: ${error.runtimeType}');
    if (messenger != null && messenger.mounted) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.localChangeFailed)));
    }
    return false;
  }
}
