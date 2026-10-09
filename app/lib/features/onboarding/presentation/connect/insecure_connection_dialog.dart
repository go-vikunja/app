import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/widgets/adaptive_dialog_action.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/server_address_display.dart';

Future<bool> confirmInsecureConnection(
  BuildContext context, {
  required Uri rootUri,
}) async {
  final l10n = context.l10n;
  final accepted = await showAdaptiveDialog<bool>(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      scrollable: true,
      title: Text(l10n.insecureDialogTitle),
      content: Text(l10n.insecureDialogBody(displayHost(rootUri))),
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
