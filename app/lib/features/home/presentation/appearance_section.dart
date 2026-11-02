import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/theme_providers.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/platform/app_language_settings.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_rows.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/theme_setting.dart';
import 'package:vikunja_mobile/features/common/presentation/settings_section.dart';

final _log = Logger('AppearanceSection');

/// The account's theme, saved to the server (not for a guest, which
/// follows the system), the device-wide choice between the system's colours
/// and the brand blue where the system has a palette (Android 12 and
/// later), and the way to the system's language page for the app (Android
/// 13 and later, iOS). Each row says where it is stored. Not shown when
/// none applies.
class AppearanceSection extends ConsumerWidget {
  const new({required this.entry, required this.signingOut, super.key});

  final RegisteredAccount entry;
  final bool signingOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guest = entry.account.isLinkShare;
    final palette = ref.watch(systemColorsProvider).value != null;
    final language =
        ref.watch(appLanguageSettingsAvailableProvider).value ?? false;
    if (guest && !palette && !language) return const SizedBox.shrink();
    final l10n = context.l10n;
    final enabled = ref.watch(useSystemColorsProvider).value ?? true;
    return SettingsSection(
      title: l10n.appearanceHeading,
      children: [
        if (!guest)
          ThemeSetting(
            key: ValueKey(entry.id),
            entry: entry,
            signingOut: signingOut,
          ),
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
