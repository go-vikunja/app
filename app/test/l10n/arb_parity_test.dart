import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter_test/flutter_test.dart';

// tool/ci/test_crowdin_export.py points this at a simulated Crowdin export.
const _arbDir = String.fromEnvironment('ARB_DIR', defaultValue: 'lib/l10n/arb');
const _template = 'en';

// gen-l10n also reads Crowdin's own codes (app_pt-BR.arb), which these tests
// and tool/l10n_progress.py would skip.
final _arbFileName = RegExp(
  r'^app_([a-z]{2,3}(?:_[A-Z][a-z]{3})?(?:_(?:[A-Z]{2}|\d{3}))?)\.arb$',
);

Map<String, Object?> _readArb(String locale) =>
    jsonDecode(File('$_arbDir/app_$locale.arb').readAsStringSync())
        as Map<String, Object?>;

Map<String, Object?> _messages(Map<String, Object?> arb) => {
  for (final MapEntry(:key, :value) in arb.entries)
    if (!key.startsWith('@')) key: value,
};

Iterable<String> _arbFileNames() =>
    Directory(_arbDir)
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .where((name) => name.endsWith('.arb'));

Set<String> _arbLocales() => _arbFileNames()
    .map((name) => _arbFileName.firstMatch(name)?.group(1))
    .nonNulls
    .toSet();

const _pluralCases = {
  '=0',
  '=1',
  '=2',
  'zero',
  'one',
  'two',
  'few',
  'many',
  'other',
};

/// The argument names of [message] as gen-l10n reads it without escaping:
/// `{name}`, `{name, plural, …}`, `{name, select, …}` and
/// `{name, date, ::skeleton}`. Throws a [FormatException] where gen-l10n
/// fails.
Set<String> _icuArguments(String message) {
  final names = <String>{};
  var at = 0;

  Never fail(String problem) => throw FormatException(problem, message, at);

  String token(String pattern, String what) {
    while (at < message.length && message[at].trim().isEmpty) {
      at++;
    }
    final match = RegExp(pattern).matchAsPrefix(message, at);
    if (match == null) fail('expected $what');
    at = match.end;
    return match[0]!;
  }

  void text({required bool nested}) {
    while (at < message.length) {
      final char = message[at++];
      if (char == '}') {
        if (nested) return;
        at--;
        fail('"}" without "{"');
      }
      if (char != '{') continue;
      names.add(token(r'\w+', 'a name'));
      if (token(r'[,\}]', '"," or "}"') == '}') continue;
      final type = token(r'\w+', 'plural, select, date or time');
      token(',', '","');
      switch (type) {
        case 'plural' || 'select':
          const casePattern = r'=\s*\d+|\w+|\}';
          final cases = <String>{};
          for (
            var selector = token(casePattern, 'a case');
            selector != '}';
            selector = token(casePattern, 'a case')
          ) {
            final name = selector.replaceAll(RegExp(r'\s'), '');
            if (type == 'plural' && !_pluralCases.contains(name)) {
              fail('"$name" is no plural case');
            }
            token(r'\{', '"{"');
            text(nested: true);
            cases.add(name);
          }
          if (!cases.contains('other')) fail('$type without an "other" case');
        case 'date' || 'time':
          token('::', '"::"');
          token(r'\w+', 'a skeleton');
          token(r'\}', '"}"');
        default:
          fail('"$type" is no argument type');
      }
    }
    if (nested) fail('"{" without "}"');
  }

  text(nested: false);
  return names;
}

/// Why [message] is no usable text in valid ICU, or null.
String? _problem(Object? message) {
  if (message is! String || message.isEmpty) return 'no text';
  try {
    _icuArguments(message);
    return null;
  } on FormatException catch (error) {
    return '${error.message} at ${error.offset}';
  }
}

void main() {
  final english = _messages(_readArb(_template));

  test('English, the template, words every message in valid ICU', () {
    final problems = [
      for (final MapEntry(:key, :value) in english.entries)
        if (_problem(value) case final problem?) '$key: $problem',
    ];

    expect(problems, isEmpty);
  });

  test('every ARB file is named app_<locale>.arb with underscores, as '
      "crowdin.yml's mapping names them", () {
    expect(
      _arbFileNames().where((name) => !_arbFileName.hasMatch(name)),
      isEmpty,
    );
  });

  test('no ARB file names another locale than its file name', () {
    for (final locale in _arbLocales()) {
      expect(
        _readArb(locale)['@@locale'],
        anyOf(isNull, locale),
        reason: 'app_$locale.arb',
      );
    }
  });

  // A translation may lack messages: Crowdin delivers what is translated
  // and approved, and English stands in for the rest (D88).
  for (final locale in _arbLocales().difference({_template})) {
    test('$locale translates only English messages, each in valid ICU with '
        "the English message's placeholders", () {
      String? problem(String key, Object? translation) {
        if (english[key] case final String source) {
          if (_problem(translation) case final problem?) return problem;
          final placeholders = _icuArguments(translation! as String);
          final expected = _icuArguments(source);
          return setEquals(placeholders, expected)
              ? null
              : 'placeholders $placeholders, English has $expected';
        }
        return 'no English message';
      }

      final problems = [
        for (final MapEntry(:key, :value) in _messages(
          _readArb(locale),
        ).entries)
          if (problem(key, value) case final found?) '$key: $found',
      ];

      expect(problems, isEmpty);
    });
  }
}
