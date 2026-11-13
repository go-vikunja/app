import 'dart:async';

import 'package:vikunja_mobile/core/previous_app/previous_app_platform.dart';
import 'package:vikunja_mobile/core/storage/secure_store.dart';

/// The previous app's native side: every call is recorded in [log] first
/// (`traces`, `cancelNotifications`, `clear`, `setAppLanguage <code>`),
/// then answered with [tracesAnswer] and [languageAnswer], or the entry of
/// [failures] for the method name is thrown. [onTraces] replaces the
/// traces answer and [onClear] the end of `clear`, e.g. to hold it open.
final class FakePreviousAppPlatform implements PreviousAppPlatform {
  new({List<String>? log}) : log = log ?? [];

  final List<String> log;
  PreviousAppTraces tracesAnswer = PreviousAppTraces.none;
  Future<PreviousAppTraces> Function()? onTraces;
  Future<void> Function()? onClear;
  bool languageAnswer = true;
  final Map<String, Exception> failures = {};

  Future<void> _record(String call, String method) async {
    log.add(call);
    if (failures[method] case final failure?) throw failure;
  }

  @override
  Future<PreviousAppTraces> traces() async {
    await _record('traces', 'traces');
    return await (onTraces?.call() ?? Future.value(tracesAnswer));
  }

  @override
  Future<void> cancelNotifications() =>
      _record('cancelNotifications', 'cancelNotifications');

  @override
  Future<void> clear() async {
    await _record('clear', 'clear');
    await onClear?.call();
  }

  @override
  Future<bool> setAppLanguage(String languageCode) async {
    await _record('setAppLanguage $languageCode', 'setAppLanguage');
    return languageAnswer;
  }
}

/// Secure storage that records every call in [log] (`read <key>`,
/// `write <key>`, `delete <key>`, `deleteAll`), never a value; a read of a
/// key in [failingReads] throws.
final class RecordingSecureStore implements SecureStore {
  new(this.log);

  final List<String> log;
  final Map<String, String> values = {};
  final Set<String> failingReads = {};

  @override
  Future<String?> read(String key) async {
    log.add('read $key');
    if (failingReads.contains(key)) throw Exception('Keystore unreadable');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    log.add('write $key');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    log.add('delete $key');
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    log.add('deleteAll');
    values.clear();
  }
}

/// What the previous app 0.1.8 stored in flutter_secure_storage for a
/// signed-in user.
Map<String, String> previousAppValues({
  String? server = 'https://vikunja.example.com/api/v1/',
  String? recentServers,
  String? refreshToken = 'previous-refresh-token',
  String? userToken = 'previous-access-token',
  String? theme,
  String? dynamicColors,
  String? locale,
}) => {
  'server-address': ?server,
  'recent-servers': ?recentServers,
  'refresh-token': ?refreshToken,
  'user-token': ?userToken,
  'theme_mode': ?theme,
  'dynamic_colors': ?dynamicColors,
  'locale_override': ?locale,
};
