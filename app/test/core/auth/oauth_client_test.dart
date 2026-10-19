import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/auth/oauth_client.dart';

void main() {
  test('the redirect uses the fixed client id and a vikunja- scheme', () {
    expect(appOAuthClient.clientId, 'dev.coderoftime.vikunja');
    expect(
      appOAuthClient.redirectUri.toString(),
      'vikunja-dev.coderoftime.vikunja://oauth/callback',
    );
    expect(appOAuthClient.redirectUri.scheme, startsWith('vikunja-'));
  });

  test('Android routes only the redirect to the callback activity', () {
    final callbackActivity = _activity(
      'com.linusu.flutter_web_auth_2.CallbackActivity',
    );

    expect(callbackActivity, contains('android:exported="true"'));
    expect(callbackActivity, contains('android.intent.action.VIEW'));
    expect(callbackActivity, contains('android.intent.category.DEFAULT'));
    expect(callbackActivity, contains('android.intent.category.BROWSABLE'));
    // The plugin completes a pending sign-in with any URI it receives, so
    // its filter must not match the task links of the same scheme.
    const callbackData =
        '<data android:scheme="$oauthCallbackScheme" android:host="oauth" '
        'android:path="/callback" />';
    expect(_dataElements(callbackActivity), [callbackData]);
    expect(appOAuthClient.redirectUri.host, 'oauth');
    expect(appOAuthClient.redirectUri.path, '/callback');
  });

  test('Android hands task links of the scheme to the main activity through '
      'a trampoline, so they never start it in another task', () {
    final trampoline = _activity('.TaskLinkActivity');
    final filters = _intentFilters(trampoline);

    expect(filters, hasLength(1));
    final taskFilter = filters.single;
    expect(taskFilter, contains('android.intent.action.VIEW'));
    expect(taskFilter, contains('android.intent.category.DEFAULT'));
    expect(taskFilter, contains('android.intent.category.BROWSABLE'));
    expect(_dataElements(taskFilter), [
      '<data android:scheme="$oauthCallbackScheme" android:host="task" />',
    ]);
    expect(trampoline, contains('android:exported="true"'));
    expect(trampoline, contains('android:noHistory="true"'));
    expect(trampoline, contains('android:excludeFromRecents="true"'));
    expect(
      _intentFilters(_activity('.MainActivity'))
          .where((filter) => filter.contains('android.intent.action.VIEW')),
      isEmpty,
    );

    final source = File(
      'android/app/src/main/kotlin/dev/coderoftime/vikunja/TaskLinkActivity.kt',
    ).readAsStringSync();
    expect(source, contains('"$oauthCallbackScheme"'));
    for (final flag in [
      'FLAG_ACTIVITY_NEW_TASK',
      'FLAG_ACTIVITY_SINGLE_TOP',
      'FLAG_ACTIVITY_CLEAR_TOP',
    ]) {
      expect(source, contains('Intent.$flag'));
    }
  });

  test('iOS registers the scheme as a URL type for task links', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final urlTypes = RegExp(
      r'<key>CFBundleURLTypes</key>\s*<array>[\s\S]*?</array>\s*</dict>'
      r'\s*</array>',
    ).firstMatch(plist)?.group(0);

    expect(urlTypes, isNotNull);
    expect(
      urlTypes,
      matches(
        RegExp(
          r'<key>CFBundleURLSchemes</key>\s*<array>\s*'
          '<string>${RegExp.escape(oauthCallbackScheme)}</string>'
          r'\s*</array>',
        ),
      ),
    );
  });

  group('accountIdFor', () {
    final root = Uri.parse('https://vikunja.example.com/sub');

    test('is the first 32 hex characters of sha256("<root>|<user id>")', () {
      // printf 'https://vikunja.example.com/sub|7' | shasum -a 256
      expect(accountIdFor(root, 7), 'bf7ff2ca96919ae8befb99ea2928a26e');
    });

    test('differs per user and per server', () {
      expect(accountIdFor(root, 7), isNot(accountIdFor(root, 8)));
      expect(
        accountIdFor(root, 7),
        isNot(accountIdFor(Uri.parse('https://vikunja.example.com'), 7)),
      );
    });
  });
}

String _activity(String name) {
  final manifest = File('android/app/src/main/AndroidManifest.xml')
      .readAsStringSync();
  final activity = RegExp(
    '<activity\\s+android:name="${RegExp.escape(name)}"'
    r'[\s\S]*?</activity>',
  ).firstMatch(manifest)?.group(0);
  expect(activity, isNotNull, reason: name);
  return activity!;
}

List<String> _intentFilters(String activity) => [
  for (final match in RegExp(
    r'<intent-filter[\s>][\s\S]*?</intent-filter>',
  ).allMatches(activity))
    match.group(0)!,
];

List<String> _dataElements(String xml) => [
  for (final match in RegExp('<data [^>]*/>').allMatches(xml)) match.group(0)!,
];
