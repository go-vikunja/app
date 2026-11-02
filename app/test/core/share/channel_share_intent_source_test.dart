import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/share/channel_share_intent_source.dart';
import 'package:vikunja_mobile/core/share/share_intent_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(ChannelShareIntentSource.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late Object? Function(MethodCall call) answer;

  setUp(() {
    calls = [];
    answer = (_) => null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return answer(call);
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  });

  ChannelShareIntentSource source() {
    final source = ChannelShareIntentSource();
    addTearDown(source.dispose);
    return source;
  }

  group('the channel format', () {
    test('text, subject and files with what the provider says', () {
      final share = incomingShareFromChannel({
        'subject': 'A page',
        'text': 'https://example.org',
        'files': [
          {
            'uri': 'content://media/1',
            'name': 'IMG_1.jpg',
            'size': 2048,
            'mime': 'image/jpeg',
          },
          {'uri': 'content://other/2', 'name': null, 'size': null},
        ],
      });

      expect(share!.subject, 'A page');
      expect(share.text, 'https://example.org');
      expect(share.files, const [
        SharedFile(
          uri: 'content://media/1',
          displayName: 'IMG_1.jpg',
          size: 2048,
          mimeType: 'image/jpeg',
        ),
        SharedFile(uri: 'content://other/2', displayName: 'file'),
      ]);
    });

    test('names from other apps are made safe; foreign schemes dropped', () {
      final share = incomingShareFromChannel({
        'files': [
          {'uri': 'content://x/1', 'name': '../../databases/vikunja.db'},
          {'uri': 'content://x/2', 'name': 'a\u202egnp.exe'},
          {'uri': 'file:///data/data/dev.coderoftime.rurana/x', 'name': 'x'},
        ],
      });

      expect(share!.files.map((file) => file.displayName), [
        '.._.._databases_vikunja.db',
        'agnp.exe',
      ]);
    });

    test('nothing usable is no share; overlong text is cut', () {
      expect(incomingShareFromChannel(null), isNull);
      expect(incomingShareFromChannel({'text': '  '}), isNull);
      expect(incomingShareFromChannel('text'), isNull);
      final long = incomingShareFromChannel({
        'text': 'x' * (maxSharedTextLength + 10),
      });
      expect(long!.text, hasLength(maxSharedTextLength));
    });
  });

  test('the pending share is read from the platform', () async {
    answer = (_) => {'text': 'Buy milk'};

    final share = await source().pending();

    expect(share!.text, 'Buy milk');
    expect(calls.single.method, 'pending');
  });

  test('a platform without the channel has no share', () async {
    messenger.setMockMethodCallHandler(channel, null);

    expect(await source().pending(), isNull);
    await source().clear();
  });

  test('a copy answers the inbox path, or says why not', () async {
    answer = (call) => switch (call.arguments) {
      {'uri': 'content://x/1'} => {'path': '/cache/share-inbox/a', 'size': 3},
      {'uri': 'content://x/2'} => throw PlatformException(code: 'too_large'),
      _ => throw PlatformException(code: 'unreadable'),
    };
    final shares = source();

    final copied = await shares.copy('content://x/1', maxBytes: 10);
    expect(copied.path, '/cache/share-inbox/a');
    expect(copied.size, 3);
    expect(calls.first.arguments, {'uri': 'content://x/1', 'maxBytes': 10});
    await expectLater(
      shares.copy('content://x/2', maxBytes: 10),
      throwsA(
        isA<SharedFileTooLarge>().having((e) => e.maxBytes, 'maxBytes', 10),
      ),
    );
    await expectLater(
      shares.copy('content://x/3', maxBytes: 10),
      throwsA(isA<SharedFileUnreadable>()),
    );
  });

  test('clear asks the platform to forget the share', () async {
    await source().clear();

    expect(calls.single.method, 'clear');
  });

  test('a share that arrives while the app runs is announced', () async {
    final shares = source();
    final next = shares.shares.first;

    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(
        const MethodCall('shared', {'subject': 'Hello'}),
      ),
      (_) {},
    );

    expect((await next).subject, 'Hello');
  });
}
