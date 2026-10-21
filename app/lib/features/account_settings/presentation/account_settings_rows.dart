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
              child: SettingHelpText(help),
            ),
          if (error != null) SettingErrorText(error),
        ],
      ),
      trailing: trailing,
      enabled: onTap != null,
      onTap: onTap,
    );
  }
}

/// A row of a settings list that is not a plain tile: a 24 dp [icon] where
/// the tiles have theirs, and [child] where their texts start, e.g. a
/// status with buttons below it or a segmented button.
class SettingsBlock extends StatelessWidget {
  const new({
    required this.icon,
    required this.child,
    this.iconColor,
    this.verticalPadding = 12,
    this.iconTopPadding = 0,
    super.key,
  });

  final IconData icon;
  final Color? iconColor;
  final Widget child;
  final double verticalPadding;

  /// Lines the icon up with a first line that is padded to a button's
  /// height.
  final double iconTopPadding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        16,
        verticalPadding,
        24,
        verticalPadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: iconTopPadding),
            child: ExcludeSemantics(
              child: Icon(icon, color: iconColor ?? colors.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// An explanation under a setting, small and muted.
class SettingHelpText extends StatelessWidget {
  const new(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// The server's refusal of a setting, in the error colour.
class SettingErrorText extends StatelessWidget {
  const new(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }
}

/// A line of explanation between the settings, e.g. why they cannot be
/// changed right now. With an [icon], its text starts where the tiles'
/// titles do.
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
          ExcludeSemantics(child: Icon(icon, color: foreground)),
          SizedBox(width: emphasized ? 12 : 16),
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
      padding: emphasized
          ? const EdgeInsets.fromLTRB(16, 8, 16, 8)
          : const EdgeInsetsDirectional.fromSTEB(16, 8, 24, 8),
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

/// "On this device" at the end of a section's header, for the settings
/// that are not saved to the account.
class OnThisDeviceMark extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => Text(context.l10n.onThisDeviceHeading);
}

/// A filled button inside a list or a card: the Material size, not the
/// theme's larger one for a screen's main action.
ButtonStyle inlineFilledButtonStyle(BuildContext context) =>
    FilledButton.styleFrom(
      minimumSize: const Size(64, 40),
      textStyle: Theme.of(context).textTheme.labelLarge,
    );

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
