import 'package:material_ui/material_ui.dart';

/// A text button among an app bar's actions, such as Save. Its label grows
/// with the text size up to [maxTextScale] only: the app bar keeps its
/// height and width, and iOS's own navigation-bar buttons stop growing at
/// the accessibility sizes too.
class AppBarTextAction extends StatelessWidget {
  const new({required this.onPressed, required this.child, super.key});

  final VoidCallback? onPressed;
  final Widget child;

  static const maxTextScale = 2.0;

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: maxTextScale,
    child: TextButton(onPressed: onPressed, child: child),
  );
}
