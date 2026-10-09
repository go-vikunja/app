import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/network/client_identity.dart';

void main() {
  test('builds the User-Agent from app and platform details', () {
    const identity = ClientIdentity(
      appVersion: '0.1.0',
      buildNumber: '7',
      platform: 'android',
      osVersion: '15',
    );

    expect(identity.userAgent, 'Taskuna/0.1.0+7 (android 15)');
  });

  test('omits missing parts and strips characters unsafe in headers', () {
    const identity = ClientIdentity(
      appVersion: '0.1.0 beta',
      buildNumber: '',
      platform: 'ios',
      osVersion: '',
    );

    expect(identity.userAgent, 'Taskuna/0.1.0beta (ios)');
  });

  test('extracts the iOS version from the dart:io description', () {
    expect(extractOsVersion('Version 17.4 (Build 21E213)'), '17.4');
    expect(extractOsVersion('Version 18.0.1 (Build 22A3370)'), '18.0.1');
    expect(extractOsVersion('unknown'), '');
  });
}
