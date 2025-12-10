import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';

part 'locale_provider.g.dart';

/// Provides an optional locale override. When null, system locale is used.
@Riverpod(keepAlive: true)
class LocaleOverride extends _$LocaleOverride {
  @override
  Future<Locale?> build() async {
    final repo = ref.read(settingsRepositoryProvider);
    final code = await repo.getLocaleOverride();
    if (code != null && code.isNotEmpty) {
      return Locale(code);
    }
    return null;
  }

  Future<void> setLocale(Locale? locale) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setLocaleOverride(locale?.languageCode);
    state = AsyncData(locale);
  }
}
