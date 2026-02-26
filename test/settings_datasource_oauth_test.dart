import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';

void main() {
  FlutterSecureStorage.setMockInitialValues({});

  group('OAuth token storage', () {
    late SettingsDatasource datasource;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      datasource = SettingsDatasource(FlutterSecureStorage());
    });

    test('getRefreshToken returns null when not set', () async {
      expect(await datasource.getRefreshToken(), isNull);
    });

    test('saveRefreshToken persists and reads back', () async {
      await datasource.saveRefreshToken('rt_abc123');
      expect(await datasource.getRefreshToken(), 'rt_abc123');
    });

    test('saveRefreshToken with null clears the value', () async {
      await datasource.saveRefreshToken('rt_abc123');
      await datasource.saveRefreshToken(null);
      expect(await datasource.getRefreshToken(), isNull);
    });

    test('getTokenExpiry returns null when not set', () async {
      expect(await datasource.getTokenExpiry(), isNull);
    });

    test('saveTokenExpiry persists and reads back', () async {
      final expiry = DateTime.utc(2026, 3, 1, 12, 0, 0);
      await datasource.saveTokenExpiry(expiry);
      expect(await datasource.getTokenExpiry(), expiry);
    });

    test('saveTokenExpiry with null clears the value', () async {
      final expiry = DateTime.utc(2026, 3, 1, 12, 0, 0);
      await datasource.saveTokenExpiry(expiry);
      await datasource.saveTokenExpiry(null);
      expect(await datasource.getTokenExpiry(), isNull);
    });

    test('getAuthType returns null when not set', () async {
      expect(await datasource.getAuthType(), isNull);
    });

    test('saveAuthType persists and reads back', () async {
      await datasource.saveAuthType('oauth');
      expect(await datasource.getAuthType(), 'oauth');
    });
  });
}
