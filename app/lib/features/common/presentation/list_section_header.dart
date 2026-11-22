import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// A section's title in the primary colour (or [color], e.g. the error
/// colour for overdue tasks), with [count] or [trailing] (e.g.
/// `Text('1 of 3 done')`, styled small and muted, or a "See all" text
/// button) at its end. An [action] (a text button) follows the count; it
/// goes to a line of its own below the title when both do not fit, as in
/// large text. Screen readers hear the count with the heading, as
/// [countLabel] where it is given.
class ListSectionHeader extends StatelessWidget {
  const new({
    required this.title,
    this.count,
    this.countLabel,
    this.trailing,
    this.action,
    this.color,
    this.padding = const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
    super.key,
  });

  final String title;
  final int? count;

  /// What screen readers hear for [count], with its unit ("1 task");
  /// without it, the bare number.
  final String? countLabel;
  final Widget? trailing;
  final Widget? action;
  final Color? color;
  final EdgeInsetsGeometry padding;

  /// The most of the header's width [trailing] takes; a longer text wraps,
  /// e.g. in large text, and leaves the title its room.
  static const _trailingShare = 0.4;

  static const _minHeight = 32.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    if (action case final action?) return _withAction(context, action);
    final trailing =
        this.trailing ??
        (count == null ? null : Text('${count!}', semanticsLabel: countLabel));
    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: padding,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _minHeight),
          child: Semantics(
            header: true,
            headingLevel: 2,
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
                      maxWidth: constraints.maxWidth * _trailingShare,
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
      ),
    );
  }

  /// The title's line is 48 dp tall like the action; the 16 dp more than
  /// the other headers' line come out of the padding above and below, so
  /// the title sits where theirs does, also when the action wraps below it.
  /// The count is shown beside the action and heard with the heading.
  Widget _withAction(BuildContext context, Widget action) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final insets = padding.resolve(Directionality.of(context));
    const taken = (kMinInteractiveDimension - _minHeight) / 2;
    final spokenCount = countLabel ?? count?.toString();
    return Padding(
      padding: insets.copyWith(
        top: math.max(insets.top - taken, 0),
        bottom: math.max(insets.bottom - taken, 0),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: kMinInteractiveDimension,
            ),
            child: Semantics(
              header: true,
              headingLevel: 2,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: color ?? colors.primary,
                      ),
                    ),
                  ),
                  if (spokenCount != null)
                    Semantics(label: spokenCount, child: const SizedBox()),
                ],
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (count case final count?)
                ExcludeSemantics(
                  child: Text(
                    '$count',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              Flexible(child: action),
            ],
          ),
        ],
      ),
    );
  }
}
