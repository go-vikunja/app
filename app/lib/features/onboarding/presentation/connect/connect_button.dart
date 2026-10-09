import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

class ConnectButton extends StatelessWidget {
  const new({required this.isConnecting, required this.onContinue, super.key});

  final bool isConnecting;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      width: double.infinity,
      child: isConnecting
          ? FilledButton(
              onPressed: null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Flexible(child: Text(l10n.connectConnecting)),
                ],
              ),
            )
          : FilledButton(
              onPressed: onContinue,
              child: Text(l10n.connectContinue),
            ),
    );
  }
}
