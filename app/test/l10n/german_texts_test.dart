import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

// docs/glossary.md, German.
void main() {
  final german = jsonDecode(
    File('lib/l10n/arb/app_de.arb').readAsStringSync(),
  ) as Map<String, Object?>;
  List<String> keysWhere(bool Function(String text) test) => [
    for (final MapEntry(:key, :value) in german.entries)
      if (!key.startsWith('@') && test(value! as String)) key,
  ];

  test('a bug is reported („einen Fehler melden“), never a „Fehlermeldung“, '
      'which reads as a message the app shows', () {
    expect(keysWhere((text) => text.contains('Fehlermeldung')), isEmpty);
  });

  test('a label that shows something says anzeigen', () {
    expect(
      keysWhere((text) => RegExp(r'(^|\s)zeigen$').hasMatch(text)),
      isEmpty,
    );
  });

  test('the texts on waiting for a sign-out use the full imperative', () {
    final short = RegExp(
      r'(?<!\p{L})(versuch|schließ|prüf|wähl|wart)(?!\p{L})',
      caseSensitive: false,
      unicode: true,
    );
    for (final text in [
      de.signOutStillFinishingSuggestion,
      de.signOutStillFinishingExplanation,
      de.guestRemoveStillFinishingExplanation,
    ]) {
      expect(text, isNot(contains(short)), reason: text);
    }
  });
}
