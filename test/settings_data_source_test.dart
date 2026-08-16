import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';

void main() {
  group('SettingsDatasource.clientCertAlias', () {
    late SettingsDatasource settings;

    setUp(() {
      FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
        <String, String>{},
      );
      settings = SettingsDatasource(const FlutterSecureStorage());
    });

    test('returns null when nothing has been stored', () async {
      expect(
        await settings.getClientCertAlias('https://one.example.com'),
        isNull,
      );
    });

    test('round-trips a stored alias', () async {
      await settings.setClientCertAlias('https://one.example.com', 'my-alias');
      expect(
        await settings.getClientCertAlias('https://one.example.com'),
        'my-alias',
      );
    });

    test('clears the alias when set to null', () async {
      await settings.setClientCertAlias('https://one.example.com', 'my-alias');
      await settings.setClientCertAlias('https://one.example.com', null);
      expect(
        await settings.getClientCertAlias('https://one.example.com'),
        isNull,
      );
    });

    test('keeps aliases isolated by server', () async {
      await settings.setClientCertAlias(
        'https://one.example.com',
        'first-alias',
      );
      await settings.setClientCertAlias(
        'https://two.example.com',
        'second-alias',
      );

      expect(
        await settings.getClientCertAlias('https://one.example.com'),
        'first-alias',
      );
      expect(
        await settings.getClientCertAlias('https://two.example.com'),
        'second-alias',
      );

      await settings.setClientCertAlias('https://one.example.com', null);
      expect(
        await settings.getClientCertAlias('https://two.example.com'),
        'second-alias',
      );
    });
  });
}
