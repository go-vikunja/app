import 'dart:async';
import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/repositories/account_settings_repository_providers.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_failure.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_rows.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_save.dart';
import 'package:vikunja_mobile/features/sync/application/offline_state.dart';

/// The account's theme (the web's colour scheme): light, dark or the
/// system's, side by side. A pick saves to the server at once, only online
/// and neither while a sign-in is needed nor while signing out.
class ThemeSetting extends ConsumerStatefulWidget {
  const new({required this.entry, required this.signingOut, super.key});

  final RegisteredAccount entry;
  final bool signingOut;

  @override
  ConsumerState<ThemeSetting> createState() => _ThemeSettingState();
}

class _ThemeSettingState extends ConsumerState<ThemeSetting>
    with AutomaticKeepAliveClientMixin {
  ColorSchema? _saving;
  String? _error;

  // A list lets go of a row scrolled out of view; a save and its outcome
  // outlive that.
  @override
  bool get wantKeepAlive => _saving != null || _error != null;

  Future<void> _save(ColorSchema schema) async {
    final repository = ref.read(accountSettingsRepositoryProvider);
    if (repository == null || _saving != null) return;
    setState(() {
      _saving = schema;
      _error = null;
    });
    updateKeepAlive();
    final outcome = await saveAccountSettings(
      context,
      repository,
      AccountSettingsField.colorScheme,
      UserSettingsChanges(colorSchema: schema),
    );
    if (!mounted) return;
    setState(() {
      _saving = null;
      if (outcome case AccountSettingsRefused(:final message)) _error = message;
    });
    updateKeepAlive();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final stored = ref.watch(
      accountSettingsProvider.select(
        (state) => state.value?.settings.colorSchema,
      ),
    );
    final offline = ref.watch(offlineProvider) != null;
    final value = _saving ?? stored ?? ColorSchema.auto;
    final canChange =
        stored != null &&
        _saving == null &&
        !offline &&
        !widget.entry.account.needsReauth &&
        !widget.signingOut;
    return _ThemeChoice(
      value: value,
      error: _error,
      saving: _saving != null,
      onChanged: canChange
          ? (schema) {
              if (schema != value) unawaited(_save(schema));
            }
          : null,
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const new({
    required this.value,
    required this.error,
    required this.saving,
    required this.onChanged,
  });

  final ColorSchema value;
  final String? error;
  final bool saving;

  /// Null shows the choice disabled.
  final ValueChanged<ColorSchema>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final error = this.error;
    final onChanged = this.onChanged;
    final enabled = onChanged != null;
    final segments = [
      (ColorSchema.light, Icons.light_mode_outlined),
      (ColorSchema.dark, Icons.dark_mode_outlined),
      (ColorSchema.auto, Icons.brightness_auto_outlined),
    ];
    final control = switch (theme.platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<ColorSchema>(
          groupValue: value,
          disabledChildren: enabled
              ? const {}
              : {for (final (schema, _) in segments) schema},
          onValueChanged: (schema) {
            if (schema != null) onChanged?.call(schema);
          },
          children: {
            for (final (schema, _) in segments)
              schema: Text(
                _themeLabel(l10n, schema),
                textAlign: TextAlign.center,
              ),
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
          return SegmentedButton<ColorSchema>(
            segments: [
              for (final (schema, icon) in segments)
                ButtonSegment(
                  value: schema,
                  icon: withIcons ? Icon(icon) : null,
                  label: Text(_themeLabel(l10n, schema)),
                ),
            ],
            selected: {value},
            // The check takes the icon's place; the fill alone is too
            // faint a sign of the choice.
            showSelectedIcon: withIcons,
            expandedInsets: EdgeInsets.zero,
            onSelectionChanged: onChanged == null
                ? null
                : (selected) => onChanged(selected.single),
          );
        },
      ),
    };
    // Disabled as a whole, so its faded texts count as a disabled control's.
    return Semantics(
      container: true,
      enabled: enabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsBlock(
            icon: Icons.contrast,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.appearanceTheme,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: enabled
                              ? null
                              : colors.onSurface.withValues(alpha: 0.38),
                        ),
                      ),
                      SettingHelpText(l10n.appearanceSavedToAccount),
                    ],
                  ),
                ),
                if (saving)
                  Semantics(
                    container: true,
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator.adaptive(
                        strokeWidth: 2,
                        semanticsLabel: l10n.accountSettingsSaving,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Across the whole width, below the icon too: inset like the
          // title, a segment has no room for its icon and the check.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [control, if (error != null) SettingErrorText(error)],
            ),
          ),
        ],
      ),
    );
  }
}

String _themeLabel(AppLocalizations l10n, ColorSchema schema) =>
    switch (schema) {
      ColorSchema.light => l10n.appearanceThemeLight,
      ColorSchema.auto => l10n.appearanceThemeSystem,
      ColorSchema.dark => l10n.appearanceThemeDark,
    };
