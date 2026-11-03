/// Method-channel stubs for the platform plugins the app reaches for.
///
/// Code under test sometimes constructs a plugin directly instead of taking it
/// through a provider (`updateWidget()` news up a `FlutterSecureStorage`, for
/// instance). Without a stub those calls throw `MissingPluginException` and
/// drown real assertions in noise. Call [mockPlatformPlugins] once per test
/// file that touches such code.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

const _secureStorage = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);
const _homeWidget = MethodChannel('home_widget');
const _packageInfo = MethodChannel('dev.fluttercommunity.plus/package_info');
const _permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
const _pathProvider = MethodChannel('plugins.flutter.io/path_provider');
const _localNotifications = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);
const _vikunja = MethodChannel('vikunja');

/// Backing store for the mocked secure storage, so writes read back.
final Map<String, String?> mockSecureStorage = {};

/// Backing store for the mocked home-widget data.
final Map<String, Object?> mockWidgetData = {};

/// The arguments of every home-widget redraw the app asked the platform for.
final List<Map<Object?, Object?>> mockWidgetRedraws = [];

/// permission_handler's wire values for `PermissionStatus`.
const int permissionDenied = 0;
const int permissionGranted = 1;

/// Installs stub handlers for every platform channel the app uses and clears
/// them again after the test. Safe to call from `setUp`.
///
/// [notificationPermission] defaults to denied, which is what a fresh test
/// environment looks like and keeps `HomePage` from reaching for the
/// local-notifications plugin, which has no host implementation.
void mockPlatformPlugins({
  String? serverAddress,
  String? refreshToken,
  int notificationPermission = permissionDenied,
}) {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  mockSecureStorage
    ..clear()
    ..['server-address'] = serverAddress
    ..['refresh-token'] = refreshToken;
  mockWidgetData.clear();
  mockWidgetRedraws.clear();

  messenger.setMockMethodCallHandler(_secureStorage, (call) async {
    switch (call.method) {
      case 'read':
        return mockSecureStorage[call.arguments['key'] as String];
      case 'write':
        mockSecureStorage[call.arguments['key'] as String] =
            call.arguments['value'] as String?;
        return null;
      case 'delete':
        mockSecureStorage.remove(call.arguments['key'] as String);
        return null;
      case 'readAll':
        return Map<String, String>.fromEntries(
          mockSecureStorage.entries
              .where((e) => e.value != null)
              .map((e) => MapEntry(e.key, e.value!)),
        );
      case 'deleteAll':
        mockSecureStorage.clear();
        return null;
      case 'containsKey':
        return mockSecureStorage.containsKey(call.arguments['key'] as String);
    }
    return null;
  });

  messenger.setMockMethodCallHandler(_homeWidget, (call) async {
    switch (call.method) {
      case 'saveWidgetData':
        mockWidgetData[call.arguments['id'] as String] = call.arguments['data'];
        return true;
      case 'getWidgetData':
        return mockWidgetData[call.arguments['id'] as String];
      case 'updateWidget':
        mockWidgetRedraws.add(call.arguments as Map<Object?, Object?>);
        return true;
      case 'registerBackgroundCallback':
        return true;
    }
    return null;
  });

  messenger.setMockMethodCallHandler(_packageInfo, (call) async {
    if (call.method == 'getAll') {
      return <String, dynamic>{
        'appName': 'Vikunja',
        'packageName': 'io.vikunja.app',
        'version': '0.1.8',
        'buildNumber': '1',
      };
    }
    return null;
  });

  messenger.setMockMethodCallHandler(_permissions, (call) async {
    switch (call.method) {
      case 'checkPermissionStatus':
        return notificationPermission;
      case 'requestPermissions':
        return <int, int>{0: notificationPermission};
    }
    return null;
  });

  messenger.setMockMethodCallHandler(
    _pathProvider,
    (call) async => '/tmp/vikunja-test',
  );

  messenger.setMockMethodCallHandler(
    _localNotifications,
    (call) async => call.method == 'initialize' ? true : null,
  );

  messenger.setMockMethodCallHandler(_vikunja, (call) async => null);

  addTearDown(() {
    for (final channel in const [
      _secureStorage,
      _homeWidget,
      _packageInfo,
      _permissions,
      _pathProvider,
      _localNotifications,
      _vikunja,
    ]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    mockSecureStorage.clear();
    mockWidgetData.clear();
    mockWidgetRedraws.clear();
  });
}

/// Records the urls the app asks the platform to open, and controls whether the
/// launch reports success.
///
/// `OAuthService.authorize` throws `browserLaunchFailed` when the launch
/// returns false, which is the quickest way to end the login flow in a test —
/// the real flow then waits ten minutes for a deep-link callback.
class FakeUrlLauncher extends UrlLauncherPlatform {
  FakeUrlLauncher({this.succeeds = false});

  final bool succeeds;
  final List<String> launched = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => succeeds;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return succeeds;
  }

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    launched.add(url);
    return succeeds;
  }

  @override
  Future<bool> supportsMode(PreferredLaunchMode mode) async => true;

  @override
  Future<bool> supportsCloseForMode(PreferredLaunchMode mode) async => false;
}

/// Installs [FakeUrlLauncher] for the test and returns it.
FakeUrlLauncher mockUrlLauncher({bool succeeds = false}) {
  final previous = UrlLauncherPlatform.instance;
  final fake = FakeUrlLauncher(succeeds: succeeds);
  UrlLauncherPlatform.instance = fake;
  addTearDown(() => UrlLauncherPlatform.instance = previous);
  return fake;
}
