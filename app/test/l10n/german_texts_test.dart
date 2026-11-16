import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

// The values only: the keys of a .strings file are English.
final _stringsValue = RegExp(
  r'^"(?:[^"\\]|\\.)*"\s*=\s*"((?:[^"\\]|\\.)*)";',
  multiLine: true,
);
final _xmlText = RegExp(r'<(string|item)\b[^>]*>([^<]*)</\1>');

List<String> _nativeTexts(File file) {
  final content = file.readAsStringSync();
  return file.path.endsWith('.strings')
      ? [for (final match in _stringsValue.allMatches(content)) match.group(1)!]
      : [for (final match in _xmlText.allMatches(content)) match.group(2)!];
}

List<File> _nativeFiles() => [
  File('android/app/src/main/res/values-de/strings.xml'),
  for (final folder in Directory('ios').listSync().whereType<Directory>())
    if (Directory('${folder.path}/de.lproj') case final german
        when german.existsSync())
      ...german.listSync().whereType<File>(),
];

List<File> _storeFiles() => [
  for (final folder in [
    '../fastlane/metadata/de-DE',
    '../fastlane/metadata/android/de-DE',
  ])
    ...Directory(folder)
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.txt')),
];

// docs/glossary.md, German.
void main() {
  final german = jsonDecode(
    File('lib/l10n/arb/app_de.arb').readAsStringSync(),
  ) as Map<String, Object?>;
  List<String> keysWhere(bool Function(String text) test) => [
    for (final MapEntry(:key, :value) in german.entries)
      if (!key.startsWith('@') && test(value! as String)) key,
  ];

  // Every German text the app and its store listings show.
  final everywhere = <String, List<String>>{
    'app_de.arb': [
      for (final MapEntry(:key, :value) in german.entries)
        if (!key.startsWith('@')) value! as String,
    ],
    for (final file in _nativeFiles()) file.path: _nativeTexts(file),
    for (final file in _storeFiles()) file.path: [file.readAsStringSync()],
  };
  Map<String, List<String>> textsMatching(RegExp pattern) => {
    for (final MapEntry(:key, :value) in everywhere.entries)
      if (value.where(pattern.hasMatch).toList() case final found
          when found.isNotEmpty)
        key: found,
  };

  test('the German texts are found in the ARB file, the native strings and '
      'the store listings', () {
    expect(
      everywhere.keys,
      containsAll([
        'android/app/src/main/res/values-de/strings.xml',
        'ios/Runner/de.lproj/InfoPlist.strings',
        'ios/VikunjaWidgets/de.lproj/Localizable.strings',
        '../fastlane/metadata/de-DE/description.txt',
        '../fastlane/metadata/android/de-DE/full_description.txt',
      ]),
    );
    for (final MapEntry(:key, :value) in everywhere.entries) {
      expect(value, isNotEmpty, reason: key);
    }
  });

  test('an account is „Account“ (der Account, die Accounts), never „Konto“, '
      "as in Vikunja's German", () {
    expect(de.tabAccount, 'Account');
    expect(de.accountsHeading, 'Accounts');
    expect(textsMatching(RegExp('kont(o|en)', caseSensitive: false)), isEmpty);
  });

  test('„Account“ is masculine', () {
    expect(
      textsMatching(
        RegExp(
          r'(?<!\p{L})(das|dieses|welches|jedes|anderes|eigenes|weiteres'
          '|neues) Account(?!s)',
          caseSensitive: false,
          unicode: true,
        ),
      ),
      isEmpty,
    );
  });

  test('compounds with „Account“ take a hyphen (Account-Einstellungen)', () {
    expect(de.accountSettingsTitle, 'Account-Einstellungen');
    expect(
      textsMatching(
        RegExp(r'\p{L}[Aa]ccount|Account(?!s?(?!\p{L}))', unicode: true),
      ),
      isEmpty,
    );
  });

  test('a username is „Anmeldename“, never „Benutzername“', () {
    expect(de.caldavUsername, 'Anmeldename');
    expect(textsMatching(RegExp('nutzername', caseSensitive: false)), isEmpty);
  });

  test('the device is „Gerät“ and another phone a „Smartphone“, never '
      '„Handy“', () {
    expect(de.connectTagline, contains('Gerät'));
    expect(de.linkShareQrHint, contains('Smartphone'));
    expect(textsMatching(RegExp('handy', caseSensitive: false)), isEmpty);
  });

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
