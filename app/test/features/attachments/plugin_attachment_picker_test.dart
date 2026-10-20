import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/features/attachments/application/plugin_attachment_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a camera shot is handed on with a readable name and its type',
    () async {
      // image_picker's default platform channel, which a test host keeps.
      const channel = MethodChannel('plugins.flutter.io/image_picker');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            ..setMockMethodCallHandler(
              channel,
              (call) async =>
                  '/data/cache/3f2c9e1a-7b4d-4c1e-9a0b-5d6e7f8a9b0c123.jpg',
            );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final picker = PluginAttachmentPicker(
        now: () => DateTime(2026, 10, 20, 14, 30, 5),
      );

      final photo = await picker.takePhoto();

      expect(photo!.path, endsWith('123.jpg'));
      expect(photo.name, 'IMG_20261020_143005.jpg');
      expect(photo.mimeType, 'image/jpeg');
    },
  );

  test("a camera shot is named the way cameras do, not after the picker's "
      'temporary file', () {
    final takenAt = DateTime(2026, 10, 20, 14, 30, 5);

    expect(
      cameraFileName(
        '/data/cache/3f2c9e1a-7b4d-4c1e-9a0b-5d6e7f8a9b0c123.JPG',
        takenAt: takenAt,
      ),
      'IMG_20261020_143005.jpg',
    );
    expect(
      cameraFileName('/tmp/image', takenAt: takenAt),
      'IMG_20261020_143005.jpg',
    );
  });

  test('photos and videos get their type from the extension', () {
    expect(mediaTypeOf('/cache/a.jpg'), 'image/jpeg');
    expect(mediaTypeOf('/cache/a.JPEG'), 'image/jpeg');
    expect(mediaTypeOf('/cache/a.png'), 'image/png');
    expect(mediaTypeOf('/cache/a.heic'), 'image/heic');
    expect(mediaTypeOf('/cache/a.mp4'), 'video/mp4');
    expect(mediaTypeOf('/cache/a.mov'), 'video/quicktime');
    expect(mediaTypeOf('/cache/a.pdf'), isNull);
    expect(mediaTypeOf('/cache/a'), isNull);
  });
}
