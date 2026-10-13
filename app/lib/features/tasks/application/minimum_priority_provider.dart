import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/settings/user_settings_providers.dart';

part 'minimum_priority_provider.g.dart';

/// The lowest priority a task row labels; the web's default until the
/// settings are read.
@riverpod
int minimumPriority(Ref ref) =>
    ref.watch(
      userSettingsProvider.select(
        (settings) => settings.value?.effectiveMinimumPriority,
      ),
    ) ??
    const UserSettings().effectiveMinimumPriority;
