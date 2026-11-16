import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_mobile/app/l10n/shipped_locales.dart';
import 'package:vikunja_mobile/app/theme/theme_providers.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/previous_install.dart';
import 'package:vikunja_mobile/core/previous_app/previous_app_platform.dart';
import 'package:vikunja_mobile/core/previous_app/previous_app_record.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';
import 'package:vikunja_mobile/core/storage/secure_store.dart';

final _log = Logger('PreviousApp');

// The previous app's secure storage keys that are read. Never its access
// token, `user-token`: the first-start wipe deletes it unread.
const _serverKey = 'server-address';
const _recentServersKey = 'recent-servers';
const _refreshTokenKey = 'refresh-token';
const _themeKey = 'theme_mode';
const _dynamicColorsKey = 'dynamic_colors';
const _localeKey = 'locale_override';
const _oldKeys = <String>[
  _serverKey,
  _recentServersKey,
  _refreshTokenKey,
  _themeKey,
  _dynamicColorsKey,
  _localeKey,
];
const _maxRecentServers = 5;

final class PreviousAppFindings {
  const new({required this.record, this.refreshToken});

  final PreviousAppRecord record;

  /// In memory only, and only from the run that read it.
  final String? refreshToken;

  @override
  String toString() => 'PreviousAppFindings($record)';
}

/// The first start after this app was installed on Android as an update
/// over the previous Vikunja app: its settings are carried over, its server
/// and refresh token found, and its notifications, jobs and stored data
/// cleared. Runs only before the first-start wipe of secure storage, on
/// the UI start.
final class PreviousAppImport {
  new({
    required this._preferences,
    required this._secureStore,
    required this._platform,
    bool? android,
    this._clearTimeout = const Duration(seconds: 4),
  }) : _android = android ?? defaultTargetPlatform == TargetPlatform.android;

  final PreferencesStore _preferences;
  final SecureStore _secureStore;
  final PreviousAppPlatform _platform;
  final bool _android;
  final Duration _clearTimeout;

  /// Null when this is not a first start, or nothing of the previous app
  /// was found. Never throws. A rerun, after the record was written, reads
  /// no secret and cleans up again.
  Future<PreviousAppFindings?> run() async {
    try {
      if (!_android || !await _isFirstStart()) return null;
      if (await PreviousAppRecord.read(_preferences) case final stored?) {
        await _cleanUp();
        return PreviousAppFindings(record: stored);
      }
      final findings = await _import();
      await _cleanUp();
      return findings;
    } on Object catch (error) {
      _log.warning('Could not import the previous app: ${error.runtimeType}');
      return null;
    }
  }

  /// The condition of `purgeSecretsLeftByPreviousInstall`, so that this
  /// runs exactly on the start whose wipe would delete what it reads.
  Future<bool> _isFirstStart() async {
    if (await _preferences.getString(installMarkerKey) != null) return false;
    final registry = await _preferences.getString(AccountRegistry.storageKey);
    return registry == null || registry.isEmpty;
  }

  Future<PreviousAppFindings?> _import() async {
    final traces = await _traces();
    final values = <String, String>{};
    for (final key in _oldKeys) {
      if (await _readSecure(key) case final value?) values[key] = value;
    }
    if (!traces.any && values.isEmpty) return null;

    final recent = _newestFirst(values[_recentServersKey]);
    final server = _normalized(values[_serverKey]) ?? recent.firstOrNull;
    await _applySettings(values);
    final record = PreviousAppRecord(
      server: server,
      recentServers: List.unmodifiable(
        recent.where((uri) => uri != server).take(_maxRecentServers),
      ),
      placedWidgets: traces.legacyWidgets,
    );
    try {
      await record.write(_preferences);
    } on Object catch (error) {
      _log.warning(
        'Could not store the previous app record: ${error.runtimeType}',
      );
    }
    final refreshToken = switch (values[_refreshTokenKey]) {
      final token? when token.isNotEmpty => token,
      _ => null,
    };
    final canKeepSession = refreshToken != null;
    _log.info(
      'Found the previous app: server ${server != null}, '
      'session $canKeepSession, widgets ${traces.legacyWidgets}',
    );
    return PreviousAppFindings(record: record, refreshToken: refreshToken);
  }

  Future<PreviousAppTraces> _traces() async {
    try {
      return await _platform.traces();
    } on Object catch (error) {
      _log.warning('Could not look for the previous app: ${error.runtimeType}');
      return PreviousAppTraces.none;
    }
  }

  Future<String?> _readSecure(String key) async {
    try {
      return await _secureStore.read(key);
    } on Object catch (error) {
      _log.warning(
        'Could not read a value of the previous app: ${error.runtimeType}',
      );
      return null;
    }
  }

  Future<void> _applySettings(Map<String, String> values) async {
    // The previous app's default was off, so its users saw the brand
    // colors; only a readable store tells that default from no value.
    if (values.isNotEmpty) {
      final systemColors = values[_dynamicColorsKey] == 'true';
      await _guarded(
        'carry over the system colors',
        () => _preferences.setString(useSystemColorsKey, '$systemColors'),
      );
    }
    // The previous app's names are those of the theme setting.
    if (values[_themeKey] case final theme?
        when theme == 'light' || theme == 'dark') {
      await _guarded(
        'carry over the theme',
        () => _preferences.setString(themeModeKey, theme),
      );
    }
    // The previous app stored a bare language code.
    if (values[_localeKey] case final language?
        when shippedLocales.any(
          (shipped) => shipped.toLanguageTag() == language,
        )) {
      await _guarded(
        'carry over the language',
        () => _platform.setAppLanguage(language),
      );
    }
  }

  /// The alarms are cancelled first: one that fires would create its
  /// channel again. The native part waits for WorkManager, which may be
  /// busy right after the update; after [_clearTimeout] it finishes without
  /// this wait, so that it cannot use up bootstrap's bound and lose what
  /// was found.
  Future<void> _cleanUp() async {
    await _guarded(
      'cancel the notifications of the previous app',
      _platform.cancelNotifications,
    );
    await _guarded(
      'clear the previous app',
      () => _platform.clear().timeout(_clearTimeout),
    );
  }

  Future<void> _guarded(String what, Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error) {
      _log.warning('Could not $what: ${error.runtimeType}');
    }
  }
}

/// The previous app added servers in the order they were first used.
List<Uri> _newestFirst(String? json) {
  if (json == null) return const [];
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return const [];
  }
  if (decoded is! List<Object?>) return const [];
  return {
    for (final entry in decoded.reversed)
      if (entry is String) ?_normalized(entry),
  }.toList();
}

Uri? _normalized(String? address) {
  if (address == null) return null;
  try {
    return normalizeServerAddress(address).root;
  } on Object {
    return null;
  }
}
