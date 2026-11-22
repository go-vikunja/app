import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';
import 'package:vikunja_mobile/app/theme/legible_color.dart';

/// A project's mark: a folder in the project's colour, as light or dark as
/// it needs to stand out from what it is drawn on, muted without one; only
/// decoration, the project's title is next to it.
class ProjectIcon extends StatelessWidget {
  const new({required this.hexColor, this.size, super.key});

  final String hexColor;

  /// Null takes the surrounding icon size.
  final double? size;

  @override
  Widget build(BuildContext context) => Icon(
    Icons.folder_outlined,
    size: size,
    color: switch (parseHexColor(hexColor)) {
      final color? => legibleIn(context, color),
      null => Theme.of(context).colorScheme.onSurfaceVariant,
    },
  );
}
