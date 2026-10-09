import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

class OverviewActions extends StatelessWidget {
  const new({
    required this.canSignIn,
    required this.onContinue,
    required this.onUseDifferentServer,
    super.key,
  });

  final bool canSignIn;
  final VoidCallback onContinue;
  final VoidCallback onUseDifferentServer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final useDifferentServer = Text(
      l10n.useDifferentServer,
      textAlign: TextAlign.center,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canSignIn) ...[
          FilledButton(
            onPressed: onContinue,
            child: Text(l10n.continueToSignIn, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: onUseDifferentServer,
            child: useDifferentServer,
          ),
        ] else
          FilledButton(
            onPressed: onUseDifferentServer,
            child: useDifferentServer,
          ),
      ],
    );
  }
}
