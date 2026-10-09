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

  test('Android routes the redirect scheme to the callback activity', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final callbackActivity = RegExp(
      r'<activity\s+android:name="com\.linusu\.flutter_web_auth_2\.CallbackActivity"'
      r'[\s\S]*?</activity>',
    ).firstMatch(manifest)?.group(0);

    expect(callbackActivity, isNotNull);
    expect(callbackActivity, contains('android:exported="true"'));
    expect(callbackActivity, contains('android.intent.action.VIEW'));
    expect(callbackActivity, contains('android.intent.category.DEFAULT'));
    expect(callbackActivity, contains('android.intent.category.BROWSABLE'));
    expect(
      callbackActivity,
      contains('<data android:scheme="$oauthCallbackScheme" />'),
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
