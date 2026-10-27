import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';

/// Under the address field: the connection settings of the address typed,
/// named exactly, because a profile for `https://host:443` is not one for
/// `https://host:3456`. Disabled while the text names no address; marked
/// when settings are stored, which is how settings without an account are
/// found again.
class ConnectionOptionsButton extends StatelessWidget {
  const new({
    required this.origin,
    required this.hasSettings,
    required this.onPressed,
    super.key,
  });

  final OriginKey? origin;
  final bool hasSettings;
  final ValueChanged<OriginKey>? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final origin = this.origin;
    final onPressed = this.onPressed;
    final enabled = origin != null && onPressed != null;
    final details = [
      if (origin != null) l10n.connectionOptionsFor('$origin'),
      if (origin != null && hasSettings) l10n.connectionOptionsSaved,
    ].join(' · ');
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        onPressed: enabled ? () => onPressed(origin) : null,
        icon: Icon(hasSettings ? Icons.tune : Icons.tune_outlined),
        label: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.connectionOptions),
            if (details.isNotEmpty)
              Text(
                details,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: enabled
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.disabledColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
