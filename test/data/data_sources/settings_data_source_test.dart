import 'package:flutter_secure_storage/flutter_secure_storage.dart'
    show
        AndroidOptions,
        AppleOptions,
        LinuxOptions,
        FlutterSecureStorage,
        WebOptions,
        WindowsOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';

class FakeSecureStorage extends FlutterSecureStorage {
  final Map<String, String> data;

  FakeSecureStorage([Map<String, String>? initial]) : data = initial ?? {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
  }
}

void main() {
  group('getRefreshInterval', () {
    test('defaults to a 15 minute sync when never configured', () async {
      final datasource = SettingsDatasource(FakeSecureStorage());

      expect(await datasource.getRefreshInterval(), 15);
    });

    test('returns an explicitly configured interval', () async {
      final datasource = SettingsDatasource(
        FakeSecureStorage({'workmanager-duration': '45'}),
      );

      expect(await datasource.getRefreshInterval(), 45);
    });

    test('returns 0 when the sync was explicitly disabled', () async {
      final datasource = SettingsDatasource(
        FakeSecureStorage({'workmanager-duration': '0'}),
      );

      expect(await datasource.getRefreshInterval(), 0);
    });
  });
}
