import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/theme_providers.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_rows.dart';
import 'package:vikunja_mobile/features/common/presentation/settings_section.dart';

/// The device-wide choice between the system's colours and the brand blue;
/// only where the system has a palette (Android 12 and later), with the
/// way to the account's colour scheme (light or dark).
class AppearanceSection extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(systemColorsProvider).value == null) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final enabled = ref.watch(useSystemColorsProvider).value ?? true;
    return SettingsSection(
      title: l10n.appearanceHeading,
      trailing: const OnThisDeviceMark(),
      children: [
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
    );
  }
}
