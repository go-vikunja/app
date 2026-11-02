import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/attachments/attachment_image_cache.dart';
import 'package:vikunja_mobile/core/attachments/attachment_images.dart';

import '../../helpers/task_details_fakes.dart';

void main() {
  late List<String> requests;
  late Map<String, FutureOr<AttachmentBlob> Function()> answers;
  late DateTime now;
  late AttachmentImageCache cache;

  String describe(int task, int attachment, AttachmentPreviewSize? preview) =>
      '$task/$attachment/${preview?.wireName ?? 'original'}';

  AttachmentBlob png(int size) =>
      AttachmentBlob(bytes: Uint8List(size), contentType: 'image/png');

  late Map<int, int?> pixelsByLength;

  AttachmentImageCache build({int maxBytes = 1000, int maxImageBytes = 600}) =>
      AttachmentImageCache(
        (task, attachment, preview) async {
          final key = describe(task, attachment, preview);
          requests.add(key);
          final answer = answers[key];
          if (answer == null) throw const NotFound(code: 4002);
          return await answer();
        },
        maxBytes: maxBytes,
        maxImageBytes: maxImageBytes,
        maxPixels: 100,
        pixelsOf: (bytes) async => pixelsByLength[bytes.length],
        now: () => now,
      );

  setUp(() {
    requests = [];
    answers = {};
    pixelsByLength = {};
    now = DateTime.utc(2026, 10, 19, 12);
    cache = build();
  });

  test('memory holds 32 MB of images, one may have 25 MB and 40 MP', () {
    final defaults = AttachmentImageCache((_, _, _) async => png(1));

    expect(defaults.maxBytes, 32 * 1024 * 1024);
    expect(defaults.maxImageBytes, 25 * 1024 * 1024);
    expect(defaults.maxImageBytes, maxAttachmentBytes);
    expect(defaults.maxPixels, 40 * 1000 * 1000);
    expect(defaults.retryAfter, const Duration(minutes: 2));
  });

  test('the pixels are read from the header without decoding', () async {
    expect(await encodedImagePixels(samplePngBytes), 1);
    expect(await encodedImagePixels(Uint8List(16)), isNull);
  });

  test('an image of too many pixels is refused for the session; what is '
      'not drawn is not measured', () async {
    answers['1/2/original'] = () => png(7);
    answers['1/3/original'] = () => png(8);
    answers['1/4/original'] = () =>
        AttachmentBlob(bytes: Uint8List(7), contentType: 'image/svg+xml');
    answers['1/5/original'] = () =>
        AttachmentBlob(bytes: Uint8List(7), contentType: 'text/plain');
    pixelsByLength[7] = 101;
    pixelsByLength[8] = 100;

    await expectLater(
      cache.load(1, 2),
      throwsA(isA<AttachmentImageTooLarge>()),
    );
    expect((await cache.load(1, 3)).bytes, hasLength(8));
    expect((await cache.load(1, 4)).isSvg, isTrue);
    expect((await cache.load(1, 5)).contentType, 'text/plain');
    cache.forgetFailures();
    now = now.add(const Duration(days: 1));
    await expectLater(
      cache.load(1, 2),
      throwsA(isA<AttachmentImageTooLarge>()),
    );

    expect(cache.remembersFailure(1, 2), isTrue);
    expect(requests.where((r) => r == '1/2/original'), hasLength(1));
  });

  test(
    'a failure that may pass can be forgotten for one image or all',
    () async {
      var offline = true;
      for (final id in [2, 3]) {
        answers['1/$id/md'] = () => offline
            ? throw const NetworkFailure(NetworkProblem.unreachable)
            : png(10);
      }
      for (final id in [2, 3]) {
        await expectLater(
          cache.load(1, id, preview: AttachmentPreviewSize.medium),
          throwsA(isA<NetworkFailure>()),
        );
      }
      await expectLater(cache.load(1, 9), throwsA(isA<NotFound>()));
      expect(
        cache.remembersFailure(1, 2, preview: AttachmentPreviewSize.medium),
        isTrue,
      );
      expect(cache.remembersFailure(1, 2), isFalse);
      offline = false;

      cache.forgetFailure(1, 2, preview: AttachmentPreviewSize.medium);
      expect(
        cache.remembersFailure(1, 2, preview: AttachmentPreviewSize.medium),
        isFalse,
      );
      expect(
        cache.remembersFailure(1, 3, preview: AttachmentPreviewSize.medium),
        isTrue,
      );
      await cache.load(1, 2, preview: AttachmentPreviewSize.medium);

      cache
        ..forgetFailures()
        ..forgetFailure(1, 9);
      await cache.load(1, 3, preview: AttachmentPreviewSize.medium);
      expect(cache.remembersFailure(1, 9), isTrue);
      await expectLater(cache.load(1, 9), throwsA(isA<NotFound>()));

      expect(requests, [
        '1/2/md',
        '1/3/md',
        '1/9/original',
        '1/2/md',
        '1/3/md',
      ]);
    },
  );

  test('a remembered failure that may pass expires', () async {
    answers['1/2/original'] = () => throw const ServerFailure(502);
    await expectLater(cache.load(1, 2), throwsA(isA<ServerFailure>()));

    expect(cache.remembersFailure(1, 2), isTrue);
    now = now.add(const Duration(minutes: 2));
    expect(cache.remembersFailure(1, 2), isFalse);
  });

  test('an image is fetched once per size and kept in memory', () async {
    answers['1/2/md'] = () => png(10);
    answers['1/2/original'] = () =>
        AttachmentBlob(bytes: Uint8List(20), contentType: 'image/svg+xml');

    final preview = await cache.load(
      1,
      2,
      preview: AttachmentPreviewSize.medium,
    );
    final again = await cache.load(1, 2, preview: AttachmentPreviewSize.medium);
    final original = await cache.load(1, 2);

    expect(preview.bytes, hasLength(10));
    expect(preview.contentType, 'image/png');
    expect(again, same(preview));
    expect(original.isSvg, isTrue);
    expect(requests, ['1/2/md', '1/2/original']);
    expect(
      cache.peek(1, 2, preview: AttachmentPreviewSize.medium),
      same(preview),
    );
    expect(cache.peek(1, 2, preview: AttachmentPreviewSize.small), isNull);
    expect(cache.cachedBytes, 30);
  });

  test('loads of the same image share one request', () async {
    final answer = Completer<AttachmentBlob>();
    answers['1/2/xl'] = () => answer.future;

    final first = cache.load(1, 2, preview: AttachmentPreviewSize.extraLarge);
    final second = cache.load(1, 2, preview: AttachmentPreviewSize.extraLarge);
    expect(cache.peek(1, 2, preview: AttachmentPreviewSize.extraLarge), isNull);
    answer.complete(png(5));

    expect(await second, same(await first));
    expect(requests, ['1/2/xl']);
  });

  test(
    'the least recently used images go once the bytes exceed the cap',
    () async {
      for (var id = 1; id <= 4; id++) {
        answers['1/$id/original'] = () => png(300);
      }

      await cache.load(1, 1);
      await cache.load(1, 2);
      await cache.load(1, 3);
      cache.peek(1, 1);
      await cache.load(1, 4);

      expect(cache.cachedBytes, 900);
      expect(cache.peek(1, 2), isNull, reason: 'least recently used');
      expect(cache.peek(1, 1), isNotNull);
      expect(cache.peek(1, 3), isNotNull);
      expect(cache.peek(1, 4), isNotNull);

      await cache.load(1, 2);
      expect(requests.where((r) => r == '1/2/original'), hasLength(2));
    },
  );

  test(
    'an image larger than the limit is refused and not asked for again',
    () async {
      answers['1/2/original'] = () => png(601);

      await expectLater(
        cache.load(1, 2),
        throwsA(isA<AttachmentImageTooLarge>()),
      );
      now = now.add(const Duration(hours: 1));
      await expectLater(
        cache.load(1, 2),
        throwsA(isA<AttachmentImageTooLarge>()),
      );

      expect(requests, ['1/2/original']);
      expect(cache.cachedBytes, 0);
    },
  );

  test(
    'a failure that may pass is answered from memory for two minutes',
    () async {
      var offline = true;
      answers['1/2/md'] = () => offline
          ? throw const NetworkFailure(NetworkProblem.unreachable)
          : png(10);

      await expectLater(
        cache.load(1, 2, preview: AttachmentPreviewSize.medium),
        throwsA(isA<NetworkFailure>()),
      );
      offline = false;
      now = now.add(const Duration(minutes: 1, seconds: 59));
      await expectLater(
        cache.load(1, 2, preview: AttachmentPreviewSize.medium),
        throwsA(isA<NetworkFailure>()),
      );
      expect(requests, ['1/2/md']);

      now = now.add(const Duration(seconds: 1));
      final image = await cache.load(
        1,
        2,
        preview: AttachmentPreviewSize.medium,
      );

      expect(image.bytes, hasLength(10));
      expect(requests, ['1/2/md', '1/2/md']);
    },
  );

  test('a missing or forbidden attachment, or one the port refused, is not '
      'asked for again', () async {
    answers['1/3/original'] = () => throw const Forbidden();
    answers['1/4/original'] = () => throw const UnexpectedResponse(
      200,
      message: 'a body larger than 26214400 bytes',
    );

    await expectLater(cache.load(1, 2), throwsA(isA<NotFound>()));
    await expectLater(cache.load(1, 3), throwsA(isA<Forbidden>()));
    await expectLater(cache.load(1, 4), throwsA(isA<UnexpectedResponse>()));
    now = now.add(const Duration(days: 1));
    await expectLater(cache.load(1, 2), throwsA(isA<NotFound>()));
    await expectLater(cache.load(1, 3), throwsA(isA<Forbidden>()));
    await expectLater(cache.load(1, 4), throwsA(isA<UnexpectedResponse>()));

    expect(requests, ['1/2/original', '1/3/original', '1/4/original']);
  });

  test('a preview the server has none of is not asked for again', () async {
    answers['1/2/md'] = () => throw const DomainError(422, code: 4038);

    await expectLater(
      cache.load(1, 2, preview: AttachmentPreviewSize.medium),
      throwsA(isA<DomainError>()),
    );
    now = now.add(const Duration(days: 1));
    cache.forgetFailures();
    await expectLater(
      cache.load(1, 2, preview: AttachmentPreviewSize.medium),
      throwsA(isA<DomainError>()),
    );

    expect(requests, ['1/2/md']);
    expect(
      attachmentImageFailureMayPass(const DomainError(422, code: 4038)),
      isFalse,
    );
    expect(
      attachmentImageFailureMayPass(const DomainError(422, code: 4039)),
      isTrue,
    );
  });

  test(
    'clearing forgets everything, also an answer still on its way',
    () async {
      final late = Completer<AttachmentBlob>();
      answers['1/1/original'] = () => png(10);
      answers['1/2/original'] = () => late.future;
      await cache.load(1, 1);
      final pending = cache.load(1, 2);

      cache.clear();
      late.complete(png(10));
      await pending;

      expect(cache.peek(1, 1), isNull);
      expect(cache.peek(1, 2), isNull);
      expect(cache.cachedBytes, 0);
    },
  );
}
