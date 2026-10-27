import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/storage/secure_store.dart';

void main() {
  test('Keychain items stay on this device and open after the first '
      'unlock', () {
    final options = FlutterSecureStore.defaultStorage.iOptions.toMap();

    expect(options['accessibility'], 'first_unlock_this_device');
    expect(options['synchronizable'], 'false');
    expect(options['useSecureEnclave'], 'false');
    expect(options['groupId'], isNull, reason: 'no shared keychain group');
  });
}
