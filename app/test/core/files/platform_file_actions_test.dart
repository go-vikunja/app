import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vikunja_mobile/core/files/file_actions.dart';
import 'package:vikunja_mobile/core/files/platform_file_actions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(PlatformFileActions.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final file = File('/cache/attachments/a/1/2/report.pdf');
  late List<MethodCall> calls;
  late List<ShareParams> shared;
  late ShareResult shareResult;

  setUp(() {
    calls = [];
    shared = [];
    shareResult = const ShareResult('x', ShareResultStatus.success);
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'openWith';
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  });

  PlatformFileActions actions({required bool android}) => PlatformFileActions(
    android: android,
    share: (params) async {
      shared.add(params);
      return shareResult;
    },
  );

  test('the type goes without parameters, an unknown one as bytes', () {
    expect(plainMimeType('text/plain; charset=utf-8'), 'text/plain');
    expect(plainMimeType('IMAGE/PNG'), 'image/png');
    expect(plainMimeType(''), 'application/octet-stream');
    expect(plainMimeType('not a type'), 'application/octet-stream');
  });

  group('Android', () {
    test('open with and save as go through the channel', () async {
      final android = actions(android: true);

      expect(
        await android.openWith(file, mimeType: 'application/pdf; x=y'),
        isTrue,
      );
      expect(
        await android.saveAs(
          file,
          fileName: 'report.pdf',
          mimeType: 'application/pdf',
        ),
        isFalse,
      );

      expect(calls.map((call) => call.method), ['openWith', 'saveAs']);
      expect(calls.first.arguments, {
        'path': file.path,
        'mime': 'application/pdf',
      });
      expect(calls.last.arguments, {
        'path': file.path,
        'name': 'report.pdf',
        'mime': 'application/pdf',
      });
      expect(shared, isEmpty);
    });

    test('sharing uses the share sheet with the file and its name', () async {
      await actions(android: true).share(
        file,
        fileName: 'Report.pdf',
        mimeType: 'application/pdf',
        origin: const Rect.fromLTWH(1, 2, 3, 4),
      );

      final params = shared.single;
      expect(params.files!.single.path, file.path);
      expect(params.files!.single.mimeType, 'application/pdf');
      expect(params.fileNameOverrides, ['Report.pdf']);
      expect(params.sharePositionOrigin, const Rect.fromLTWH(1, 2, 3, 4));
    });
  });

  group('iOS', () {
    test('open with and save as use the share sheet', () async {
      final ios = actions(android: false);

      expect(await ios.openWith(file, mimeType: 'application/pdf'), isTrue);
      shareResult = const ShareResult('', ShareResultStatus.dismissed);
      expect(
        await ios.saveAs(
          file,
          fileName: 'report.pdf',
          mimeType: 'application/pdf',
        ),
        isFalse,
      );

      expect(shared, hasLength(2));
      expect(calls, isEmpty);
    });
  });
}
