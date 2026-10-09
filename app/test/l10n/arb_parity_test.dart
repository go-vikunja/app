import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _readArb(String locale) =>
    jsonDecode(File('lib/l10n/arb/app_$locale.arb').readAsStringSync())
        as Map<String, Object?>;

Set<String> _messageKeys(Map<String, Object?> arb) =>
    arb.keys.where((key) => !key.startsWith('@')).toSet();

Set<String> _placeholders(String message) =>
    RegExp(r'\{(\w+)\}')
        .allMatches(message)
        .map((match) => match.group(1)!)
        .toSet();

Set<String> _arbLocales() => Directory('lib/l10n/arb')
    .listSync()
    .map((file) => RegExp(r'app_(\w+)\.arb$').firstMatch(file.path)?.group(1))
    .nonNulls
    .toSet();

void main() {
  final english = _readArb('en');
  final german = _readArb('de');

  test('the Android per-app language config lists every ARB locale', () {
    final config = File('android/app/src/main/res/xml/locales_config.xml')
        .readAsStringSync();
    final configured = RegExp('android:name="([^"]+)"')
        .allMatches(config)
        .map((match) => match.group(1))
        .toSet();

    expect(configured, _arbLocales());
  });

  test('German translates every English message and nothing else', () {
    expect(_messageKeys(german), _messageKeys(english));
  });

  test('translations keep the placeholders of the English message', () {
    for (final key in _messageKeys(english)) {
      expect(
        _placeholders(german[key]! as String),
        _placeholders(english[key]! as String),
        reason: key,
      );
    }
  });
}
