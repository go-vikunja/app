import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

class SignInButton extends StatelessWidget {
  const new({
    required this.label,
    required this.isSigningIn,
    required this.onPressed,
    this.waitingLabel,
    super.key,
  });

  final String label;
  final bool isSigningIn;
  final VoidCallback onPressed;

  /// Shown while signing in; "Waiting for sign-in…" without it.
  final String? waitingLabel;

  @override
  Widget build(BuildContext context) {
    if (!isSigningIn) {
      return FilledButton(
        onPressed: onPressed,
        child: Text(label, textAlign: TextAlign.center),
      );
    }
    return FilledButton(
      onPressed: null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Flexible(child: Text(waitingLabel ?? context.l10n.signInWaiting)),
        ],
      ),
    );
  }
}
