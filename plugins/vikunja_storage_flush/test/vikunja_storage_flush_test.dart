import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_storage_flush/vikunja_storage_flush.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(StorageFlush.channel, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(StorageFlush.channel, null);
  });

  test('the channel carries the plugin name', () {
    expect(StorageFlush.channel.name, 'io.vikunja.vikunja_storage_flush');
  });

  test('asks Android to flush the named file', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    await StorageFlush.flushSharedPreferences('FlutterSecureStorage');

    expect(calls.single.method, 'flushSharedPreferences');
    expect(calls.single.arguments, {'name': 'FlutterSecureStorage'});
  });

  test('does nothing on iOS, whose Keychain writes at once', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    await StorageFlush.flushSharedPreferences('FlutterSecureStorage');

    expect(calls, isEmpty);
  });

  test('a failed flush reaches the caller', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          StorageFlush.channel,
          (call) async => throw PlatformException(code: 'io'),
        );

    await expectLater(
      StorageFlush.flushSharedPreferences('FlutterSecureStorage'),
      throwsA(isA<PlatformException>()),
    );
  });
}
