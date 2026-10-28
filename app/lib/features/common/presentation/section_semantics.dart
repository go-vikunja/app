import 'package:material_ui/material_ui.dart';

/// Around a section's heading and its content: keeps the heading a node of
/// its own. Without it, a list item that holds the heading and a single
/// tappable row becomes one node, and the heading turns into that row's
/// button.
class SectionSemantics extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Semantics(explicitChildNodes: true, child: child);
}
