import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart' show AttachmentBlob;
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/attachments/attachment_image_cache.dart';
import 'package:vikunja_mobile/core/attachments/attachment_images.dart';
import 'package:vikunja_mobile/core/attachments/image_disk_cache.dart';
import 'package:vikunja_mobile/features/description_editor/application/editor_image_previews.dart';
import 'package:vikunja_mobile/features/description_editor/application/editor_protocol.dart';

import '../../helpers/task_details_fakes.dart';

void main() {
  final apiRoot = Uri.parse('https://vikunja.example.com/api/v1');
  String url(int task, int attachment) =>
      'https://vikunja.example.com/api/v1/tasks/$task/attachments/$attachment';
  // A 1×1 PNG.
  final pixel = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==',
  );
  AttachmentImage png(Uint8List bytes) =>
      AttachmentImage(bytes: bytes, contentType: 'image/png');
  // A 1×1 GIF, which a decode would turn into a PNG.
  final gif = base64Decode(
    'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
  );

  Future<Uint8List> pngOf(int width, int height) async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFF2196F3),
    );
    final image = await recorder.endRecording().toImage(width, height);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  int pngWidth(String? dataUrl) {
    expect(dataUrl, startsWith('data:image/png;base64,'));
    final bytes = base64Decode(dataUrl!.split(',').last);
    expect(bytes.sublist(1, 4), utf8.encode('PNG'));
    return ByteData.sublistView(bytes, 16, 20).getUint32(0);
  }

  test('the page names its images; the app sends previews by URL', () {
    expect(
      decodeEditorMessage(
        jsonEncode({
          'type': 'images',
          'token': 't',
          'urls': [url(1, 2), 3, url(1, 4)],
        }),
        token: 't',
      ),
      isA<EditorImagesWanted>().having((e) => e.urls, 'urls', [
        url(1, 2),
        url(1, 4),
      ]),
    );
    final script = EditorMessages.imagePreviews({
      url(1, 2): 'data:image/png;base64,AAAA',
    }, token: 't');
    expect(script, startsWith('window.vikunja.receive('));
    expect(script, contains('"type":"imagePreviews"'));
    expect(script, contains('"token":"t"'));
  });

  test('each image is loaded at the preview size and sent once, the original '
      'where the server has no preview, nothing for what fails or is no '
      'attachment of the server', () async {
    final images = FakeAttachmentImages();
    images.images[(1, 2, AttachmentPreviewSize.extraLarge)] = png(pixel);
    images.failures[(1, 3, AttachmentPreviewSize.extraLarge)] =
        const DomainError(422, code: 4038);
    images.images[(1, 3, null)] = png(pixel);
    final previews = EditorImagePreviews(
      images: images,
      roots: [apiRoot],
      attachmentsOf: (taskId) async => [
        TaskAttachment(
          id: 3,
          taskId: 1,
          name: 'b.png',
          mime: 'image/png',
          size: pixel.length,
        ),
      ],
    );
    final sent = <Map<String, String>>[];

    await previews.provide([
      url(1, 2),
      url(1, 3),
      url(1, 9),
      'https://elsewhere.example.org/api/v1/tasks/1/attachments/2',
    ], (preview) async => sent.add(preview));
    await previews.provide([url(1, 2)], (preview) async => sent.add(preview));

    final expected = 'data:image/png;base64,${base64Encode(pixel)}';
    expect(sent, [
      {url(1, 2): expected},
      {url(1, 3): expected},
    ]);
    expect(images.loads, ['1 2 xl', '1 3 xl', '1 3 original', '1 9 xl']);
  });

  test(
    "an image under the server root or under /info's frontend_url is the "
    "account's, loaded by its ids; the same path on another host is not",
    () async {
      final images = FakeAttachmentImages();
      images.images[(1, 2, AttachmentPreviewSize.extraLarge)] = png(pixel);
      images.images[(1, 3, AttachmentPreviewSize.extraLarge)] = png(pixel);
      final previews = EditorImagePreviews(
        images: images,
        roots: [
          Uri.parse('https://api.example.org/vikunja/'),
          Uri.parse('https://tasks.example.org/sub/'),
        ],
      );
      final sent = <Map<String, String>>[];
      const server =
          'https://api.example.org/vikunja/api/v1/tasks/1/attachments/2';
      const web = 'https://tasks.example.org/sub/api/v2/tasks/1/attachments/3';

      await previews.provide([
        server,
        web,
        'https://tasks.example.org/api/v2/tasks/1/attachments/4',
        'https://evil.example/sub/api/v2/tasks/1/attachments/5',
      ], (preview) async => sent.add(preview));

      final expected = 'data:image/png;base64,${base64Encode(pixel)}';
      expect(sent, [
        {server: expected},
        {web: expected},
      ]);
      expect(images.loads, ['1 2 xl', '1 3 xl']);
    },
  );

  test('a preview over the budget is left out for good, and those after it '
      'that fit are still sent', () async {
    final images = FakeAttachmentImages()..fallback = png(pixel);
    images.images[(1, 3, AttachmentPreviewSize.extraLarge)] = png(
      Uint8List(300),
    );
    // Two of the pixel's previews (118 characters each), not the large one.
    final previews = EditorImagePreviews(
      images: images,
      roots: [apiRoot],
      maxTotalChars: 250,
    );
    final sent = <Map<String, String>>[];
    Iterable<String> sentUrls() => sent.map((preview) => preview.keys.single);

    await previews.provide([
      url(1, 2),
      url(1, 3),
      url(1, 4),
    ], (preview) async => sent.add(preview));
    expect(sentUrls(), [url(1, 2), url(1, 4)]);

    await previews.provide([
      url(1, 2),
      url(1, 3),
      url(1, 4),
      url(1, 5),
    ], (preview) async => sent.add(preview));
    expect(sentUrls(), [url(1, 2), url(1, 4)]);
    expect(images.loads, ['1 2 xl', '1 3 xl', '1 4 xl', '1 5 xl']);
  });

  test('like the task sheet, the first ten images load, the others keep '
      'their placeholder, and an image named twice takes one place', () async {
    final images = FakeAttachmentImages()..fallback = png(pixel);
    final previews = EditorImagePreviews(images: images, roots: [apiRoot]);
    final sent = <Map<String, String>>[];
    const again = 'https://vikunja.example.com/tasks/1/attachments/1';

    await previews.provide([
      url(1, 1),
      again,
      for (var id = 1; id <= 12; id++) url(1, id),
    ], (preview) async => sent.add(preview));
    await previews.provide([url(1, 13)], (preview) async => sent.add(preview));

    expect(maxImagesByThemselves, 10);
    expect(images.loads, [
      '1 1 xl',
      for (var id = 1; id <= 10; id++) '1 $id xl',
    ]);
    expect(sent.map((preview) => preview.keys.single), [
      url(1, 1),
      again,
      for (var id = 2; id <= 10; id++) url(1, id),
    ]);
  });

  test('a file the list names as no image takes none of the ten places, '
      'one it names without a type does', () async {
    final images = FakeAttachmentImages()..fallback = png(pixel);
    TaskAttachment listed(int id, String mime) =>
        TaskAttachment(id: id, taskId: 1, name: 'f$id', mime: mime, size: 9);
    final previews = EditorImagePreviews(
      images: images,
      roots: [apiRoot],
      attachmentsOf: (taskId) async => [
        listed(2, 'application/pdf'),
        listed(3, ''),
        listed(4, 'application/octet-stream'),
      ],
    );

    await previews.provide([
      for (var id = 1; id <= 12; id++) url(1, id),
    ], (preview) async {});

    expect(images.loads, [
      for (final id in [1, 3, 4, 5, 6, 7, 8, 9, 10, 11]) '1 $id xl',
    ]);
  });

  test('an image uploaded on this page loads past the ten', () async {
    final images = FakeAttachmentImages()..fallback = png(pixel);
    final previews = EditorImagePreviews(images: images, roots: [apiRoot]);
    final sent = <Map<String, String>>[];
    await previews.provide([
      for (var id = 1; id <= 11; id++) url(1, id),
    ], (preview) async => sent.add(preview));
    images.loads.clear();

    previews.addUploaded(
      const TaskAttachment(
        id: 500,
        taskId: 1,
        name: 'IMG_1.jpg',
        mime: 'image/jpeg',
        size: 2048,
      ),
    );
    await previews.provide([
      for (var id = 1; id <= 11; id++) url(1, id),
      url(1, 500),
    ], (preview) async => sent.add(preview));

    expect(images.loads, ['1 500 xl']);
    expect(sent, hasLength(11));
    expect(sent.last.keys.single, url(1, 500));
  });

  test('once the budget is spent, nothing more is asked for', () async {
    final images = FakeAttachmentImages()..fallback = png(pixel);
    // The pixel's preview has 118 characters.
    final previews = EditorImagePreviews(
      images: images,
      roots: [apiRoot],
      maxTotalChars: 236,
    );

    await previews.provide([
      for (var id = 1; id <= 4; id++) url(1, id),
    ], (preview) async {});

    expect(images.loads, ['1 1 xl', '1 2 xl']);
  });

  test('once closed, nothing more is loaded, and an image still loading is '
      'not sent', () async {
    final images = FakeAttachmentImages()..fallback = png(pixel);
    final previews = EditorImagePreviews(images: images, roots: [apiRoot]);
    images.beforeLoad = (_) async => previews.close();
    final sent = <Map<String, String>>[];

    await previews.provide([
      url(1, 2),
      url(1, 3),
    ], (preview) async => sent.add(preview));
    await previews.provide([url(1, 4)], (preview) async => sent.add(preview));

    expect(sent, isEmpty);
    expect(images.loads, ['1 2 xl']);
  });

  test('offline after a restart, the page still gets the previews the app '
      'kept, the original where the server has no preview, never an '
      'SVG', () async {
    final folder = Directory.systemTemp.createTempSync('editor_previews');
    addTearDown(() => folder.deleteSync(recursive: true));
    final svg = utf8.encode('<svg/>');
    final online = <(int, AttachmentPreviewSize?), AttachmentBlob>{
      (2, AttachmentPreviewSize.extraLarge): AttachmentBlob(
        bytes: pixel,
        contentType: 'image/png',
      ),
      (3, null): AttachmentBlob(bytes: gif, contentType: 'image/gif'),
      (4, null): AttachmentBlob(
        bytes: Uint8List.fromList(svg),
        contentType: 'image/svg+xml',
      ),
    };
    final listed = [
      TaskAttachment(
        id: 3,
        taskId: 1,
        name: 'c.gif',
        mime: 'image/gif',
        size: gif.length,
      ),
      TaskAttachment(
        id: 4,
        taskId: 1,
        name: 'd.svg',
        mime: 'image/svg+xml',
        size: svg.length,
      ),
    ];
    final fetches = <String>[];
    var reachable = true;
    Future<List<Map<String, String>>> openPage() async {
      final disk = ImageDiskCache(() async => folder);
      final images = AttachmentImageCache((task, attachment, preview, _) async {
        fetches.add('$attachment ${preview?.wireName ?? 'original'}');
        if (!reachable) throw const NetworkFailure(NetworkProblem.unreachable);
        return online[(attachment, preview)] ??
            (throw const DomainError(422, code: 4038));
      }, disk: disk);
      final sent = <Map<String, String>>[];
      await EditorImagePreviews(
        images: images,
        roots: [apiRoot],
        attachmentsOf: (taskId) async => listed,
      ).provide([url(1, 2), url(1, 3), url(1, 4)], (preview) async {
        sent.add(preview);
      });
      await disk.flush();
      return sent;
    }

    final shown = await openPage();
    expect(fetches, ['2 xl', '3 xl', '3 original']);
    fetches.clear();
    reachable = false;
    final shownOffline = await openPage();

    expect(shown, [
      {url(1, 2): 'data:image/png;base64,${base64Encode(pixel)}'},
      {url(1, 3): 'data:image/gif;base64,${base64Encode(gif)}'},
    ]);
    expect(shownOffline, shown);
    expect(fetches, ['2 xl', '3 xl']);
  });

  test('where the server has no preview, the original is loaded only for an '
      "image the task's list names at up to 8 MiB, or one in memory; a file "
      'it names as no image is not asked for', () async {
    final images = FakeAttachmentImages()..fallback = png(pixel);
    for (final id in [3, 4, 5, 6, 7, 8, 9]) {
      images.failures[(1, id, AttachmentPreviewSize.extraLarge)] =
          const DomainError(422, code: 4038);
    }
    await images.load(1, 7);
    images.loads.clear();
    TaskAttachment listed(int id, String mime, int size) =>
        TaskAttachment(id: id, taskId: 1, name: 'f$id', mime: mime, size: size);
    final previews = EditorImagePreviews(
      images: images,
      roots: [apiRoot],
      attachmentsOf: (taskId) async => [
        listed(3, 'image/png', maxStandInBytes),
        listed(4, 'image/png', maxStandInBytes + 1),
        listed(5, 'application/pdf', 2048),
        listed(6, 'image/svg+xml', 2048),
        listed(9, 'image/png', 0),
      ],
    );
    final sent = <Map<String, String>>[];

    await previews.provide([
      for (final id in [3, 4, 5, 6, 7, 8, 9]) url(1, id),
    ], (preview) async => sent.add(preview));

    expect(sent.map((preview) => preview.keys.single), [url(1, 3), url(1, 7)]);
    expect(images.loads, [
      '1 3 xl',
      '1 3 original',
      '1 4 xl',
      '1 7 xl',
      '1 7 original',
      '1 8 xl',
      '1 9 xl',
    ]);
  });

  test("each task's list is read once per page load, and one that cannot be "
      'read counts as none', () async {
    final images = FakeAttachmentImages()..fallback = png(pixel);
    images.failures[(1, 3, AttachmentPreviewSize.extraLarge)] =
        const DomainError(422, code: 4038);
    images.failures[(2, 4, AttachmentPreviewSize.extraLarge)] =
        const DomainError(422, code: 4038);
    final reads = <int>[];
    EditorImagePreviews pageLoad() => EditorImagePreviews(
      images: images,
      roots: [apiRoot],
      attachmentsOf: (taskId) async {
        reads.add(taskId);
        await Future<void>.delayed(Duration.zero);
        if (taskId == 2) throw Exception('no database');
        return [
          TaskAttachment(
            id: 3,
            taskId: 1,
            name: 'c.png',
            mime: 'image/png',
            size: pixel.length,
          ),
        ];
      },
    );
    final previews = pageLoad();
    final sent = <Map<String, String>>[];
    void send(Map<String, String> preview) => sent.add(preview);

    await Future.wait([
      previews.provide([
        url(1, 2),
        url(1, 3),
        url(2, 4),
      ], (preview) async => send(preview)),
      previews.provide([
        url(2, 5),
        url(1, 6),
      ], (preview) async => send(preview)),
    ]);

    expect(reads, [1, 2]);
    expect(sent.map((preview) => preview.keys.single).toSet(), {
      url(1, 2),
      url(1, 3),
      url(2, 5),
      url(1, 6),
    });
    expect(images.loads, isNot(contains('2 4 original')));

    await pageLoad().provide([url(1, 7)], (preview) async => send(preview));
    expect(reads, [1, 2, 1]);
  });

  test('an attachment uploaded on this page counts as listed, so its '
      'original stands in for a missing preview', () async {
    final images = FakeAttachmentImages()..fallback = png(pixel);
    for (final id in [500, 501]) {
      images.failures[(1, id, AttachmentPreviewSize.extraLarge)] =
          const DomainError(422, code: 4038);
    }
    final previews = EditorImagePreviews(
      images: images,
      roots: [apiRoot],
      attachmentsOf: (taskId) async => [
        TaskAttachment(
          id: 2,
          taskId: 1,
          name: 'b.png',
          mime: 'image/png',
          size: pixel.length,
        ),
      ],
    );
    final sent = <Map<String, String>>[];
    await previews.provide([url(1, 2)], (preview) async => sent.add(preview));

    previews
      ..addUploaded(
        const TaskAttachment(
          id: 500,
          taskId: 1,
          name: 'IMG_1.heic',
          mime: 'image/heic',
          size: 2048,
        ),
      )
      ..addUploaded(
        const TaskAttachment(
          id: 501,
          taskId: 1,
          name: 'IMG_2.webp',
          mime: 'image/webp',
          size: maxStandInBytes + 1,
        ),
      );
    await previews.provide([
      url(1, 500),
      url(1, 501),
    ], (preview) async => sent.add(preview));

    expect(sent.map((preview) => preview.keys.single), [
      url(1, 2),
      url(1, 500),
    ]);
    expect(images.loads, ['1 2 xl', '1 500 xl', '1 500 original', '1 501 xl']);
  });

  testWidgets('an SVG or what is no image gets no preview, however it '
      'decodes', (tester) async {
    for (final image in [
      AttachmentImage(
        bytes: Uint8List.fromList(utf8.encode('<svg/>')),
        contentType: 'image/svg+xml',
      ),
      AttachmentImage(bytes: pixel, contentType: 'application/octet-stream'),
      AttachmentImage(bytes: pixel, contentType: 'text/plain'),
    ]) {
      expect(
        await tester.runAsync(() => editorPreviewDataUrl(image)),
        isNull,
        reason: image.contentType,
      );
    }
  });

  testWidgets('an image too large to pass but no wider than maxWidth passes '
      'as it came, as a PNG of it would be no smaller', (tester) async {
    expect(
      await tester.runAsync(
        () => editorPreviewDataUrl(
          AttachmentImage(bytes: gif, contentType: 'image/gif'),
          maxBytes: 0,
        ),
      ),
      'data:image/gif;base64,${base64Encode(gif)}',
    );
  });

  testWidgets('an image too large to pass and wider than maxWidth is decoded '
      'maxWidth wide into a PNG', (tester) async {
    final preview = await tester.runAsync(() async {
      final wide = await pngOf(4, 2);
      return await editorPreviewDataUrl(png(wide), maxBytes: 0, maxWidth: 2);
    });
    expect(pngWidth(preview), 2);
  });

  testWidgets('an image type the page does not take is decoded into a PNG, '
      'at most maxWidth wide', (tester) async {
    final previews = await tester.runAsync(() async {
      final wide = await pngOf(4, 2);
      return [
        await editorPreviewDataUrl(
          AttachmentImage(bytes: pixel, contentType: 'image/bmp'),
        ),
        await editorPreviewDataUrl(
          AttachmentImage(bytes: wide, contentType: 'image/bmp'),
          maxWidth: 2,
        ),
      ];
    });
    expect(previews!.map(pngWidth), [1, 2]);
  });
}
