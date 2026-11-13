import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/legal/app_licenses.dart';

final _british = RegExp(
  'colour|favourit|licenc|organis|recognis|centre|behaviour|neighbour'
  r'|\bgrey\b|\bbins?\b|\btick(s|ed|ing)?\b|full stop|\btyres?\b',
  caseSensitive: false,
);

// ARB keys keep their British spelling, and descriptions name them.
final _identifier = RegExp(r'\b[a-z]+(?:[A-Z][A-Za-z0-9]*)+\b');

final _unofficial = RegExp('unofficial|inoffiziell', caseSensitive: false);

Map<String, Object?> _arb(String locale) =>
    jsonDecode(File('lib/l10n/arb/app_$locale.arb').readAsStringSync())
        as Map<String, Object?>;

/// The messages by key and the descriptions by `@key`.
Map<String, String> _arbTexts(String locale) => {
  for (final MapEntry(:key, :value) in _arb(locale).entries)
    if (!key.startsWith('@'))
      key: value! as String
    else if (value case {'description': final String description})
      key: description,
};

/// The widget extension's strings in [language], whatever its folder is
/// called.
List<File> _widgetStrings(String language) => [
  for (final folder in Directory('ios').listSync().whereType<Directory>())
    for (final name in ['Localizable.strings', 'Localizable.stringsdict'])
      File('${folder.path}/$language.lproj/$name'),
].where((file) => file.existsSync()).toList();

final _quoted = RegExp(r'"((?:[^"\\]|\\.)*)"');
final _xmlText = RegExp(r'<(string|item)\b[^>]*>([^<]*)</\1>');

/// The texts of a native strings file, without its comments.
List<String> _nativeTexts(File file) {
  final content = file.readAsStringSync();
  return file.path.endsWith('.strings')
      ? [for (final match in _quoted.allMatches(content)) match.group(1)!]
      : [for (final match in _xmlText.allMatches(content)) match.group(2)!];
}

Map<String, List<String>> _offenders(
  List<File> files,
  bool Function(String text) offends,
) {
  final offenders = <String, List<String>>{};
  for (final file in files) {
    final texts = _nativeTexts(file);
    expect(texts, isNotEmpty, reason: file.path);
    if (texts.where(offends).toList() case final found when found.isNotEmpty) {
      offenders[file.path] = found;
    }
  }
  return offenders;
}

bool _isBritish(String text) =>
    _british.hasMatch(text.replaceAll(_identifier, ''));

void main() {
  test("English messages and descriptions use US spelling and the web's "
      'terms', () {
    final british = {
      for (final MapEntry(:key, :value) in _arbTexts('en').entries)
        if (_isBritish(value)) key: value,
    };

    expect(british, isEmpty);
  });

  test('no message or description names Rurana, except the notice on its '
      'name and logo', () {
    final named = [
      for (final locale in ['en', 'de'])
        for (final MapEntry(:key, :value) in _arbTexts(locale).entries)
          if (key != 'aboutNameAndLogo' && value.contains('Rurana'))
            '$locale $key',
    ];

    expect(named, isEmpty);
  });

  test('no message calls the app unofficial', () {
    final unofficial = [
      for (final locale in ['en', 'de'])
        for (final MapEntry(:key, :value) in _arbTexts(locale).entries)
          if (_unofficial.hasMatch(value)) '$locale $key',
    ];

    expect(unofficial, isEmpty);
  });

  test('the native English texts use US spelling and the name', () {
    final widgets = _widgetStrings('en');
    expect(widgets, isNotEmpty);

    final offenders = _offenders([
      File('android/app/src/main/res/values/strings.xml'),
      ...widgets,
    ], (text) => _isBritish(text) || text.contains('Rurana'));

    expect(offenders, isEmpty);
  });

  test("the app's own words in the Material Icons notice use US spelling", () {
    final [entry] = parseNotices(
      File(LegalAssets.materialIcons).readAsStringSync(),
    );
    final paragraphs = [
      for (final paragraph in entry.paragraphs) paragraph.text,
    ];
    final licence = paragraphs.indexOf('Attribution 4.0 International');
    expect(licence, greaterThan(0));

    expect(paragraphs.take(licence).where(_isBritish), isEmpty);
  });

  test('the native German texts use the name', () {
    final widgets = _widgetStrings('de');
    expect(widgets, isNotEmpty);

    final offenders = _offenders([
      File('android/app/src/main/res/values-de/strings.xml'),
      File('ios/Runner/de.lproj/InfoPlist.strings'),
      ...widgets,
    ], (text) => text.contains('Rurana'));

    expect(offenders, isEmpty);
  });
}
