import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/widgets/adaptive_dialog_action.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/server_address_display.dart';

/// With [httpsFailed] the question says that https did not answer, which
/// is what blocking it on the network looks like, rather than that the
/// server uses http.
Future<bool> confirmInsecureConnection(
  BuildContext context, {
  required Uri rootUri,
  bool httpsFailed = false,
}) async {
  final l10n = context.l10n;
  final host = displayHost(rootUri);
  final accepted = await showAdaptiveDialog<bool>(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      scrollable: true,
      title: Text(
        httpsFailed
            ? l10n.insecureFallbackDialogTitle
            : l10n.insecureDialogTitle,
      ),
      content: Text(
        httpsFailed
            ? l10n.insecureFallbackDialogBody(host)
            : l10n.insecureDialogBody(host),
      ),
      actions: [
        AdaptiveDialogAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.insecureDialogCancel),
        ),
        AdaptiveDialogAction(
          onPressed: () => Navigator.of(context).pop(true),
          isDestructive: true,
          child: Text(l10n.insecureDialogContinue),
        ),
      ],
    ),
  );
  return accepted ?? false;
}
