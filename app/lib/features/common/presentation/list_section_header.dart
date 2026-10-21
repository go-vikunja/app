import 'package:material_ui/material_ui.dart';

/// A section's title in the primary colour (or [color], e.g. the error
/// colour for overdue tasks), with [count] or [trailing] (e.g.
/// `Text('1 of 3 done')`, styled small and muted, or a "See all" text
/// button) at its end.
class ListSectionHeader extends StatelessWidget {
  const new({
    required this.title,
    this.count,
    this.trailing,
    this.color,
    this.padding = const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
    super.key,
  });

  final String title;
  final int? count;
  final Widget? trailing;
  final Color? color;
  final EdgeInsetsGeometry padding;

  /// The most of the screen's width [trailing] takes; a longer text wraps,
  /// e.g. in large text, and leaves the title its room.
  static const _trailingShare = 0.4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final trailing =
        this.trailing ?? (count == null ? null : Text('${count!}'));
    return Padding(
      padding: padding,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Semantics(
          header: true,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: color ?? colors.primary,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * _trailingShare,
                  ),
                  child: DefaultTextStyle.merge(
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.end,
                    child: trailing,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
