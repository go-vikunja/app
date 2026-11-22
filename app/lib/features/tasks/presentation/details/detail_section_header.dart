import 'package:material_ui/material_ui.dart';

/// A section heading in the detail sheet in the primary colour, with
/// [trailing] (a count, a summary or a text button) after it, at the end
/// when both fit on one line, and icon buttons as [actions] at the end.
/// The heading and [trailing] are nodes of their own, so that heading
/// navigation lands on the title alone and the summary follows it.
class DetailSectionHeader extends StatelessWidget {
  const new({
    required this.title,
    this.trailing,
    this.actions = const [],
    super.key,
  });

  final String title;
  final Widget? trailing;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final trailing = this.trailing;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        20,
        16,
        actions.isEmpty ? 20 : 8,
        4,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Row(
          children: [
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Semantics(
                    container: true,
                    header: true,
                    headingLevel: 2,
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colors.primary,
                      ),
                    ),
                  ),
                  if (trailing != null)
                    Semantics(
                      container: true,
                      child: DefaultTextStyle.merge(
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                        child: trailing,
                      ),
                    ),
                ],
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}
