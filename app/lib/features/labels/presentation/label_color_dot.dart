import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';

/// A label's colour as a dot, an outlined ring without one; only
/// decoration, the title is next to it.
class LabelColorDot extends StatelessWidget {
  const new({required this.hexColor, this.size = 16, super.key});

  final String hexColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = parseHexColor(hexColor);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: color == null ? colors.outline : colors.outlineVariant,
          ),
        ),
      ),
    );
  }
}
