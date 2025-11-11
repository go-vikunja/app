import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/domain/repositories/settings_repository.dart';

/// Provides an optional locale override. When null, system locale is used.
final localeOverrideProvider =
    StateNotifierProvider<LocaleOverrideNotifier, Locale?>((ref) {
      final settingsRepo = ref.read(settingsRepositoryProvider);
      return LocaleOverrideNotifier(settingsRepo);
    });

class LocaleOverrideNotifier extends StateNotifier<Locale?> {
  final SettingsRepository _repo;
  LocaleOverrideNotifier(this._repo) : super(null) {
    _load();
  }

  Future<void> _load() async {
    final code = await _repo.getLocaleOverride();
    if (code != null && code.isNotEmpty) {
      state = Locale(code);
    }
  }

  Future<void> setLocale(Locale? locale) async {
    await _repo.setLocaleOverride(locale?.languageCode);
    state = locale;
  }
}
