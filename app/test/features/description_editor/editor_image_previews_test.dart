import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/attachments/attachment_images.dart';
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

  test('previews over the budget are left out', () async {
    final images = FakeAttachmentImages()..fallback = png(pixel);
    final previews = EditorImagePreviews(
      images: images,
      apiRoot: apiRoot,
      maxTotalChars: 150,
    );
    final sent = <Map<String, String>>[];

    await previews.provide([
      url(1, 2),
      url(1, 3),
    ], (preview) async => sent.add(preview));

    expect(sent.map((preview) => preview.keys.single), [url(1, 2)]);
  });

  test('an SVG gets no preview', () async {
    expect(
      await editorPreviewDataUrl(
        AttachmentImage(
          bytes: Uint8List.fromList(utf8.encode('<svg/>')),
          contentType: 'image/svg+xml',
        ),
      ),
      isNull,
    );
  });

  testWidgets('an image too large to pass is decoded into a PNG', (
    tester,
  ) async {
    final preview = await tester.runAsync(
      () => editorPreviewDataUrl(png(pixel), maxBytes: 0),
    );
    expect(preview, startsWith('data:image/png;base64,'));
    final decoded = base64Decode(preview!.split(',').last);
    expect(decoded.sublist(1, 4), utf8.encode('PNG'));
  });
}
