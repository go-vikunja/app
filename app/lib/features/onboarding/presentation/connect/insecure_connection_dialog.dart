import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
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
        _AdaptiveDialogAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.insecureDialogCancel),
        ),
        _AdaptiveDialogAction(
          onPressed: () => Navigator.of(context).pop(true),
          isDestructive: true,
          child: Text(l10n.insecureDialogContinue),
        ),
      ],
    ),
  );
  return accepted ?? false;
}

class _AdaptiveDialogAction extends StatelessWidget {
  const new({
    required this.onPressed,
    required this.child,
    this.isDestructive = false,
  });

  final VoidCallback onPressed;
  final Widget child;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => CupertinoDialogAction(
        onPressed: onPressed,
        isDefaultAction: !isDestructive,
        isDestructiveAction: isDestructive,
        child: child,
      ),
      _ => TextButton(onPressed: onPressed, child: child),
    };
  }
}
