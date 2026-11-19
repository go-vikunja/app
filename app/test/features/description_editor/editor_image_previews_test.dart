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
    final previews = EditorImagePreviews(images: images, apiRoot: apiRoot);
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

  test('a preview over the budget is left out for good, and those after it '
      'that fit are still sent', () async {
    final images = FakeAttachmentImages()..fallback = png(pixel);
    images.images[(1, 3, AttachmentPreviewSize.extraLarge)] = png(
      Uint8List(300),
    );
    // Two of the pixel's previews (118 characters each), not the large one.
    final previews = EditorImagePreviews(
      images: images,
      apiRoot: apiRoot,
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

  test('once closed, nothing more is loaded, and an image still loading is '
      'not sent', () async {
    final images = FakeAttachmentImages()..fallback = png(pixel);
    final previews = EditorImagePreviews(images: images, apiRoot: apiRoot);
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
    final svg = AttachmentBlob(
      bytes: Uint8List.fromList(utf8.encode('<svg/>')),
      contentType: 'image/svg+xml',
    );
    final online = <(int, AttachmentPreviewSize?), AttachmentBlob>{
      (2, AttachmentPreviewSize.extraLarge): AttachmentBlob(
        bytes: pixel,
        contentType: 'image/png',
      ),
      (3, null): AttachmentBlob(bytes: gif, contentType: 'image/gif'),
      (4, null): svg,
    };
    var reachable = true;
    Future<List<Map<String, String>>> openPage() async {
      final disk = ImageDiskCache(() async => folder);
      final images = AttachmentImageCache((task, attachment, preview) async {
        if (!reachable) throw const NetworkFailure(NetworkProblem.unreachable);
        return online[(attachment, preview)] ??
            (throw const DomainError(422, code: 4038));
      }, disk: disk);
      final sent = <Map<String, String>>[];
      await EditorImagePreviews(images: images, apiRoot: apiRoot).provide(
        [url(1, 2), url(1, 3), url(1, 4)],
        (preview) async {
          sent.add(preview);
        },
      );
      await disk.flush();
      return sent;
    }

    final shown = await openPage();
    reachable = false;
    final shownOffline = await openPage();

    expect(shown, [
      {url(1, 2): 'data:image/png;base64,${base64Encode(pixel)}'},
      {url(1, 3): 'data:image/gif;base64,${base64Encode(gif)}'},
    ]);
    expect(shownOffline, shown);
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
