import 'dart:async';
import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/theme_providers.dart';
import 'package:vikunja_mobile/core/platform/app_language_settings.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_rows.dart';
import 'package:vikunja_mobile/features/common/presentation/settings_section.dart';

final _log = Logger('AppearanceSection');

/// The settings of this device, the same for every account and for guests:
/// the theme, the choice between the system's colours and the brand blue
/// where the system has a palette (Android 12 and later), and the way to
/// the system's language page for the app (Android 13 and later, iOS).
class AppearanceSection extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(systemColorsProvider).value != null;
    final language =
        ref.watch(appLanguageSettingsAvailableProvider).value ?? false;
    final l10n = context.l10n;
    final enabled = ref.watch(useSystemColorsProvider).value ?? true;
    return SettingsSection(
      title: l10n.appearanceHeading,
      children: [
        const _ThemeRow(),
        if (palette)
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.palette_outlined),
            title: Text(l10n.appearanceSystemColors),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.appearanceSystemColorsSubtitle),
                SettingHelpText(l10n.appearanceOnThisDevice),
              ],
            ),
            value: enabled,
            onChanged: (value) => unawaited(
              ref.read(useSystemColorsProvider.notifier).set(enabled: value),
            ),
          ),
        if (language) const _AppLanguageTile(),
      ],
    );
  }
}

/// Light, dark or the system's, side by side; a pick applies at once.
class _ThemeRow extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final value = ref.watch(themeModeProvider);
    void pick(ThemeMode mode) {
      if (mode != value) {
        unawaited(ref.read(themeChoiceProvider.notifier).set(mode));
      }
    }

    final segments = [
      (ThemeMode.light, Icons.light_mode_outlined),
      (ThemeMode.dark, Icons.dark_mode_outlined),
      (ThemeMode.system, Icons.brightness_auto_outlined),
    ];
    final control = switch (theme.platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<ThemeMode>(
          groupValue: value,
          onValueChanged: (mode) {
            if (mode != null) pick(mode);
          },
          children: {
            for (final (mode, _) in segments)
              mode: Text(_themeLabel(l10n, mode), textAlign: TextAlign.center),
          },
        ),
      ),
      _ => LayoutBuilder(
        builder: (context, constraints) {
          // The icons go first when the labels would have to wrap.
          final labelStyle = theme.textTheme.labelLarge;
          final scaler = MediaQuery.textScalerOf(context);
          final widestLabel = segments
              .map((segment) {
                final painter = TextPainter(
                  text: TextSpan(
                    text: _themeLabel(l10n, segment.$1),
                    style: labelStyle,
                  ),
                  textDirection: Directionality.of(context),
                  textScaler: scaler,
                  maxLines: 1,
                )..layout();
                final width = painter.width;
                painter.dispose();
                return width;
              })
              .reduce(math.max);
          const iconAndPadding = 12 + 18 + 8 + 16;
          final withIcons =
              constraints.maxWidth / segments.length >=
              widestLabel + iconAndPadding + 2;
          return SegmentedButton<ThemeMode>(
            segments: [
              for (final (mode, icon) in segments)
                ButtonSegment(
                  value: mode,
                  icon: withIcons ? Icon(icon) : null,
                  label: Text(_themeLabel(l10n, mode)),
                ),
            ],
            selected: {value},
            // The check takes the icon's place; the fill alone is too
            // faint a sign of the choice.
            showSelectedIcon: withIcons,
            expandedInsets: EdgeInsets.zero,
            onSelectionChanged: (selected) => pick(selected.single),
          );
        },
      ),
    };
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsBlock(
            icon: Icons.contrast,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.appearanceTheme, style: theme.textTheme.bodyLarge),
                SettingHelpText(l10n.appearanceOnThisDevice),
              ],
            ),
          ),
          // Across the whole width, below the icon too: inset like the
          // title, a segment has no room for its icon and the check.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: control,
          ),
        ],
      ),
    );
  }
}

String _themeLabel(AppLocalizations l10n, ThemeMode mode) => switch (mode) {
  ThemeMode.light => l10n.appearanceThemeLight,
  ThemeMode.system => l10n.appearanceThemeSystem,
  ThemeMode.dark => l10n.appearanceThemeDark,
};

class _AppLanguageTile extends ConsumerWidget {
  const new();

  Future<void> _open(WidgetRef ref) async {
    try {
      final opened = await ref.read(appLanguageSettingsProvider).open();
      if (!opened) _log.info('The app language settings did not open');
    } on Object catch (error) {
      _log.warning(
        'Could not open the app language settings: ${error.runtimeType}',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ListTile(
      leading: const Icon(Icons.language),
      title: Text(l10n.appLanguageTitle),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.appLanguageName),
          SettingHelpText(l10n.appearanceOnThisDevice),
        ],
      ),
      trailing: const Icon(Icons.open_in_new),
      onTap: () => unawaited(_open(ref)),
    );
  }
}
