import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/theme_providers.dart';
import 'package:vikunja_mobile/core/platform/app_language_settings.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_rows.dart';
import 'package:vikunja_mobile/features/common/presentation/settings_section.dart';

final _log = Logger('AppearanceSection');

/// The way to the system's language page for the app (Android 13 and
/// later, iOS), and the device-wide choice between the system's colours
/// and the brand blue where the system has a palette (Android 12 and
/// later), with the way to the account's colour scheme (light or dark).
/// Not shown when neither applies.
class AppearanceSection extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(systemColorsProvider).value != null;
    final language =
        ref.watch(appLanguageSettingsAvailableProvider).value ?? false;
    if (!palette && !language) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final enabled = ref.watch(useSystemColorsProvider).value ?? true;
    return SettingsSection(
      title: l10n.appearanceHeading,
      trailing: const OnThisDeviceMark(),
      children: [
        if (language) const _AppLanguageTile(),
        if (palette) ...[
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.palette_outlined),
            title: Text(l10n.appearanceSystemColors),
            subtitle: Text(l10n.appearanceSystemColorsSubtitle),
            value: enabled,
            onChanged: (value) => unawaited(
              ref.read(useSystemColorsProvider.notifier).set(enabled: value),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(56, 0, 24, 4),
            child: Text(
              l10n.appearanceLightDarkHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

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
      subtitle: Text(l10n.appLanguageName),
      trailing: const Icon(Icons.open_in_new),
      onTap: () => unawaited(_open(ref)),
    );
  }
}
