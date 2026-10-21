import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

/// A setting whose value is picked in a sheet: the [value] under the
/// [title], an explanation and the server's refusal below it.
class SettingChoiceTile extends StatelessWidget {
  const new({
    required this.title,
    required this.value,
    required this.onTap,
    this.help,
    this.error,
    this.leading,
    this.trailing,
    super.key,
  });

  final String title;
  final String value;
  final String? help;
  final String? error;
  final Widget? leading;
  final Widget? trailing;

  /// Null shows the row disabled.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final help = this.help;
    final error = this.error;
    return ListTile(
      leading: leading,
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value),
          if (help != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                help,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                error,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.error,
                ),
              ),
            ),
        ],
      ),
      trailing: trailing,
      enabled: onTap != null,
      onTap: onTap,
    );
  }
}

/// A line of explanation between the settings, e.g. why they cannot be
/// changed right now.
class SettingsNote extends StatelessWidget {
  const new({
    required this.text,
    this.icon,
    this.action,
    this.emphasized = false,
    super.key,
  });

  final String text;
  final IconData? icon;
  final Widget? action;

  /// On a container colour, for what holds the whole page back.
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = emphasized
        ? colors.onSecondaryContainer
        : colors.onSurfaceVariant;
    final icon = this.icon;
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          ExcludeSemantics(child: Icon(icon, size: 20, color: foreground)),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: foreground,
                  ),
                ),
              ),
              ?action,
            ],
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: emphasized
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(padding: const EdgeInsets.all(12), child: content),
            )
          : content,
    );
  }
}

/// Under the app bar while a change is sent; takes its height also when
/// idle, so the page does not jump with every change.
class SavingProgressBar extends StatelessWidget implements PreferredSizeWidget {
  const new({required this.saving, super.key});

  static const height = 4.0;

  final bool saving;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) => saving
      ? LinearProgressIndicator(
          minHeight: height,
          semanticsLabel: context.l10n.accountSettingsSaving,
        )
      : const SizedBox(height: height);
}
