import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/app/l10n/shipped_locales.dart';

/// How a store listing's language names the app's languages: the line
/// "• {label}: A, B {and} C." and the names by language tag.
typedef _Listing = ({String label, String and, Map<String, String> names});

const _listings = <String, _Listing>{
  'en-US': (
    label: 'Languages',
    and: 'and',
    names: {'en': 'English', 'de': 'German'},
  ),
  'de-DE': (
    label: 'Sprachen',
    and: 'und',
    names: {'en': 'Englisch', 'de': 'Deutsch'},
  ),
};

String _enumeration(List<String> names, String and) => names.length == 1
    ? names.single
    : '${names.take(names.length - 1).join(', ')} $and ${names.last}';

void main() {
  final shipped = {for (final locale in shippedLocales) locale.toLanguageTag()};

  test('every store listing language is covered here', () {
    final listed = {
      for (final folder in Directory(
        '../fastlane/metadata/android',
      ).listSync().whereType<Directory>())
        folder.uri.pathSegments.lastWhere((segment) => segment.isNotEmpty),
    };

    expect(listed, _listings.keys.toSet());
  });

  for (final MapEntry(key: locale, value: listing) in _listings.entries) {
    test('the $locale descriptions name exactly the shipped languages', () {
      expect(
        listing.names.keys,
        containsAll(shipped),
        reason:
            'A language was added to shippedLocales: add its name here and to '
            'the "${listing.label}" line of the $locale descriptions.',
      );
      final byName = {
        for (final MapEntry(:key, :value) in listing.names.entries) value: key,
      };
      for (final path in [
        '../fastlane/metadata/android/$locale/full_description.txt',
        '../fastlane/metadata/$locale/description.txt',
      ]) {
        final lines = [
          for (final match in RegExp(
            '^• ${listing.label}: (.*)\\.\$',
            multiLine: true,
          ).allMatches(File(path).readAsStringSync()))
            match[1]!,
        ];
        expect(lines, hasLength(1), reason: path);
        final named = lines.single.split(RegExp(', | ${listing.and} '));

        expect(
          {for (final name in named) byName[name] ?? name},
          shipped,
          reason: path,
        );
        expect(named, hasLength(shipped.length), reason: path);
        expect(_enumeration(named, listing.and), lines.single, reason: path);
      }
    });
  }
}
