import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/features/attachments/application/channel_document_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(ChannelDocumentPicker.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late List<Object?> picked;
  late Object? Function(MethodCall call) copy;

  setUp(() {
    calls = [];
    picked = [];
    copy = (call) => {'path': '/cache/picked/${calls.length}', 'size': 1};
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'pick' => picked,
        'copy' => copy(call),
        _ => throw MissingPluginException(),
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  });

  Future<({List<String> files, List<String> tooLarge, List<String> failed})>
  pick({int maxBytes = 100}) async {
    final result = await ChannelDocumentPicker().pick(
      maxBytes: maxBytes,
      imagesOnly: false,
      multiple: true,
    );
    return (
      files: [for (final file in result.files) '${file.name} ${file.path}'],
      tooLarge: result.tooLarge,
      failed: result.failed,
    );
  }

  test('asks for the kind and count of files, copies each one within the '
      'limit with that limit', () async {
    picked = [
      {
        'uri': 'content://docs/1',
        'name': 'a.pdf',
        'size': 10,
        'mime': 'application/pdf',
      },
    ];

    final result = await ChannelDocumentPicker().pick(
      maxBytes: 100,
      imagesOnly: true,
      multiple: false,
    );

    expect(calls.first.arguments, {'imagesOnly': true, 'multiple': false});
    expect(calls.last.method, 'copy');
    expect(calls.last.arguments, {'uri': 'content://docs/1', 'maxBytes': 100});
    expect(result.files.single.path, '/cache/picked/2');
    expect(result.files.single.name, 'a.pdf');
    expect(result.files.single.mimeType, 'application/pdf');
  });

  test('a file the provider says is above the limit is never copied', () async {
    picked = [
      {
        'uri': 'content://docs/1',
        'name': 'huge.mov',
        'size': 101,
        'mime': null,
      },
      {'uri': 'content://docs/2', 'name': 'b.txt', 'size': 100, 'mime': null},
    ];

    final result = await pick();

    expect(
      calls.where((call) => call.method == 'copy').map((c) => c.arguments),
      [
        {'uri': 'content://docs/2', 'maxBytes': 100},
      ],
    );
    expect(result.tooLarge, ['huge.mov']);
    expect(result.files, ['b.txt /cache/picked/2']);
  });

  test('one without a known size is too large when the capped copy says '
      'so; one that cannot be read fails alone', () async {
    picked = [
      {
        'uri': 'content://docs/1',
        'name': 'big.bin',
        'size': null,
        'mime': null,
      },
      {'uri': 'content://docs/2', 'name': 'gone.txt', 'size': 1, 'mime': null},
      {'uri': 'content://docs/3', 'name': 'ok.txt', 'size': 1, 'mime': null},
    ];
    copy = (call) => switch ((call.arguments as Map)['uri']) {
      'content://docs/1' => throw PlatformException(code: 'too_large'),
      'content://docs/2' => throw PlatformException(code: 'unreadable'),
      _ => {'path': '/cache/picked/ok', 'size': 1},
    };

    final result = await pick();

    expect(result.tooLarge, ['big.bin']);
    expect(result.failed, ['gone.txt']);
    expect(result.files, ['ok.txt /cache/picked/ok']);
  });

  test(
    'names from other apps are made safe; a cancelled pick is empty',
    () async {
      picked = [
        {
          'uri': 'content://docs/1',
          'name': '../../x\u202e.txt',
          'size': 1,
          'mime': null,
        },
      ];
      expect((await pick()).files, ['.._.._x.txt /cache/picked/2']);

      picked = [];
      calls.clear();
      final cancelled = await pick();
      expect(cancelled.files, isEmpty);
      expect(calls.map((call) => call.method), ['pick']);
    },
  );
}
