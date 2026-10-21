import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/theme_providers.dart';

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
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.appearanceHeading,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.appearanceSystemColors),
            subtitle: Text(l10n.appearanceSystemColorsSubtitle),
            value: enabled,
            onChanged: (value) => unawaited(
              ref.read(useSystemColorsProvider.notifier).set(enabled: value),
            ),
          ),
          Text(
            l10n.appearanceLightDarkHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
