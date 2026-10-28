import 'package:material_ui/material_ui.dart';

/// An app bar's title as the screen's level-1 heading. The app bar marks
/// its title a header, but without a level, which is no heading for
/// TalkBack or VoiceOver; the level merges into that node. A header flag
/// here would split it into two nodes instead: two headers conflict.
class ScreenTitle extends StatelessWidget {
  const new(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    assert(() {
      final appBar = context.findAncestorWidgetOfExactType<AppBar>();
      return appBar != null && !appBar.excludeHeaderSemantics;
    }(), 'ScreenTitle is the title of an AppBar that marks it a header');
    return Semantics(headingLevel: 1, child: Text(text));
  }
}
