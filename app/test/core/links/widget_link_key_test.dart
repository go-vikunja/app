import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/auth/previous_install.dart';
import 'package:vikunja_mobile/core/links/widget_link_key.dart';

import '../../helpers/auth_fakes.dart';

void main() {
  late MemoryPreferencesStore preferences;

  setUp(() => preferences = MemoryPreferencesStore());

  String? stored() => preferences.values[widgetLinkKeyPreference];

  test('a key is 32 random bytes in base64url without padding', () {
    final key = newWidgetLinkKey();

    expect(key, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
    expect(base64Url.decode('$key='), hasLength(32));
    expect(newWidgetLinkKey(), isNot(key));
  });

  group('at the UI start', () {
    test('a fresh install gets a new key, also over one left behind', () async {
      preferences.values[widgetLinkKeyPreference] = newWidgetLinkKey();
      final left = stored();

      final key = await prepareWidgetLinkKey(preferences);

      expect(key, isNot(left));
      expect(stored(), key);
    });

    test('an existing install keeps its key', () async {
      preferences.values[installMarkerKey] = '1';
      final kept = newWidgetLinkKey();
      preferences.values[widgetLinkKeyPreference] = kept;

      expect(await prepareWidgetLinkKey(preferences), kept);
      expect(stored(), kept);
    });

    test('an existing install without a readable key gets one', () async {
      preferences.values[installMarkerKey] = '1';
      final created = await prepareWidgetLinkKey(preferences);
      expect(stored(), created);

      preferences.values[widgetLinkKeyPreference] = 'not a key';
      final replaced = await prepareWidgetLinkKey(preferences);
      expect(replaced, isNot(created));
      expect(widgetLinkKeyMatches(replaced, stored()), isTrue);
    });
  });

  group('reading', () {
    test('returns the stored key and null without one', () async {
      expect(await readWidgetLinkKey(preferences), isNull);

      final key = await ensureWidgetLinkKey(preferences, rotate: false);

      expect(await readWidgetLinkKey(preferences), key);
    });

    test('never creates one, and an unreadable store means none', () async {
      expect(await readWidgetLinkKey(preferences), isNull);
      expect(stored(), isNull);

      await ensureWidgetLinkKey(preferences, rotate: false);
      preferences.failNextRead.add(widgetLinkKeyPreference);
      expect(await readWidgetLinkKey(preferences), isNull);
    });
  });

  group('matching', () {
    final key = newWidgetLinkKey();

    test('accepts the key itself', () {
      expect(widgetLinkKeyMatches(key, key), isTrue);
      expect(widgetLinkKeyMatches('$key=', key), isTrue);
    });

    test('refuses a missing, wrong, short or malformed key', () {
      final other = newWidgetLinkKey();
      expect(widgetLinkKeyMatches(null, key), isFalse);
      expect(widgetLinkKeyMatches(key, null), isFalse);
      expect(widgetLinkKeyMatches(other, key), isFalse);
      expect(widgetLinkKeyMatches(key.substring(0, 42), key), isFalse);
      expect(widgetLinkKeyMatches('${key}AAAA', key), isFalse);
      expect(widgetLinkKeyMatches('', key), isFalse);
      expect(widgetLinkKeyMatches('***not*base64url***', key), isFalse);
      expect(widgetLinkKeyMatches('', ''), isFalse);
    });

    test('differs in the last byte only', () {
      final bytes = base64Url.decode('$key=');
      bytes[31] ^= 1;
      final nearly = base64Url.encode(bytes).replaceAll('=', '');

      expect(widgetLinkKeyMatches(nearly, key), isFalse);
    });
  });
}
