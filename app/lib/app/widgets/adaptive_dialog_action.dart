import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

class AdaptiveDialogAction extends StatelessWidget {
  const new({
    required this.onPressed,
    required this.child,
    this.isDestructive = false,
    super.key,
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
      _ => TextButton(
        onPressed: onPressed,
        style: isDestructive
            ? TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              )
            : null,
        child: child,
      ),
    };
  }
}
