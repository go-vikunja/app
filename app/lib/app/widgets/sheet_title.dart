import 'package:material_ui/material_ui.dart';

/// A sheet's title, its level-1 heading, in the same size in every sheet.
class SheetTitle extends StatelessWidget {
  const new(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    headingLevel: 1,
    child: Text(text, style: Theme.of(context).textTheme.titleLarge),
  );
}
