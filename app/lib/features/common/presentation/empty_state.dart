import 'package:material_ui/material_ui.dart';

class EmptyState extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.body,
    this.isScreenTitle = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  /// Whether [title] is the title of a screen without an app bar: a level-1
  /// heading that also names the route on Android, as an app bar's title
  /// does. Otherwise a level-2 heading.
  final bool isScreenTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Icon(icon, size: 56, color: colors.primary)),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            headingLevel: isScreenTitle ? 1 : 2,
            namesRoute: isScreenTitle
                ? switch (theme.platform) {
                    TargetPlatform.iOS || TargetPlatform.macOS => null,
                    _ => true,
                  }
                : null,
            child: Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
