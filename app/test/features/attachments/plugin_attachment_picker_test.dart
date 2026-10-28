import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/security/app_excursions.dart';
import 'package:vikunja_mobile/features/attachments/application/attachment_picker.dart';
import 'package:vikunja_mobile/features/attachments/application/plugin_attachment_picker.dart';

// image_picker's default platform channel, which a test host keeps.
const _imagePicker = MethodChannel('plugins.flutter.io/image_picker');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test(
    'a camera shot is handed on with a readable name and its type',
    () async {
      messenger.setMockMethodCallHandler(
        _imagePicker,
        (call) async =>
            '/data/cache/3f2c9e1a-7b4d-4c1e-9a0b-5d6e7f8a9b0c123.jpg',
      );
      addTearDown(() => messenger.setMockMethodCallHandler(_imagePicker, null));
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

  group('a pick Android relaunched the activity under', () {
    late AppExcursions excursions;
    late List<String> calls;

    /// Never answers a pick; [lost] answers the n-th look into the lost
    /// picks.
    PluginAttachmentPicker setUpPicker(
      WidgetTester tester, {
      Map<String, Object?>? Function(int look)? lost,
    }) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      excursions = AppExcursions(now: () => DateTime.utc(2026, 10, 20, 14));
      addTearDown(excursions.dispose);
      calls = [];
      var looks = 0;
      messenger.setMockMethodCallHandler(_imagePicker, (call) {
        calls.add(call.method);
        if (call.method != 'retrieve') return Completer<Object?>().future;
        return Future.value(lost?.call(++looks));
      });
      addTearDown(() => messenger.setMockMethodCallHandler(_imagePicker, null));
      return PluginAttachmentPicker(
        excursions: excursions,
        now: () => DateTime(2026, 10, 20, 14, 30, 5),
      );
    }

    Map<String, Object?> lostImages(List<String> paths) => {
      'type': 'image',
      'path': paths.last,
      'pathList': paths,
    };

    int retrieves() => calls.where((method) => method == 'retrieve').length;

    testWidgets('recovers a camera shot, named and typed like any other', (
      tester,
    ) async {
      final picker = setUpPicker(
        tester,
        lost: (look) => look == 3 ? lostImages(['/data/cache/lost.jpg']) : null,
      );
      PickedFile? photo;
      unawaited(picker.takePhoto().then((value) => photo = value));
      await tester.pump();
      expect(calls, ['pickImage']);

      excursions.abandon();
      await tester.pump(PluginAttachmentPicker.lostPickPoll);
      expect(photo, isNull);
      await tester.pump(PluginAttachmentPicker.lostPickPoll);

      expect(photo?.path, '/data/cache/lost.jpg');
      expect(photo?.name, 'IMG_20261020_143005.jpg');
      expect(photo?.mimeType, 'image/jpeg');
      expect(excursions.active, isFalse);
    });

    testWidgets('recovers every photo and video picked', (tester) async {
      final picker = setUpPicker(
        tester,
        lost: (_) => {
          'type': 'media',
          'path': '/data/cache/b.mp4',
          'pathList': ['/data/cache/a.jpg', '/data/cache/b.mp4'],
        },
      );
      List<PickedFile>? files;
      unawaited(picker.pickPhotos().then((value) => files = value));
      await tester.pump();

      excursions.abandon();
      await tester.pump();

      expect(files?.map((file) => (file.name, file.mimeType)), [
        ('a.jpg', 'image/jpeg'),
        ('b.mp4', 'video/mp4'),
      ]);
    });

    testWidgets('stops looking after the first lost pick', (tester) async {
      final picker = setUpPicker(
        tester,
        lost: (look) => look == 2 ? lostImages(['/data/cache/a.jpg']) : null,
      );
      List<PickedFile>? files;
      unawaited(
        picker
            .pickPhotos(imagesOnly: true, multiple: false)
            .then((value) => files = value),
      );
      await tester.pump();

      excursions.abandon();
      await tester.pump(PluginAttachmentPicker.lostPickWait);

      expect(files?.single.path, '/data/cache/a.jpg');
      expect(retrieves(), 2);
    });

    testWidgets('counts a pick still lost after the wait as a cancel', (
      tester,
    ) async {
      final picker = setUpPicker(tester);
      var taken = false;
      PickedFile? photo;
      List<PickedFile>? files;
      unawaited(
        picker.takePhoto().then((value) {
          taken = true;
          photo = value;
        }),
      );
      unawaited(picker.pickPhotos().then((value) => files = value));
      await tester.pump();

      excursions.abandon();
      await tester.pump(
        PluginAttachmentPicker.lostPickWait -
            PluginAttachmentPicker.lostPickPoll,
      );
      expect(taken, isFalse);
      expect(files, isNull);
      await tester.pump(PluginAttachmentPicker.lostPickPoll);

      expect(taken, isTrue);
      expect(photo, isNull);
      expect(files, isEmpty);
      final looks = retrieves();
      await tester.pump(const Duration(minutes: 1));
      expect(retrieves(), looks);
    });

    // Only the method-channel platform hands a lost error over:
    // image_picker_android 0.8.13+25 drops a lost pick with an error and no
    // paths, so on Android it ends like a cancel after lostPickWait.
    testWidgets('fails with the error the lost pick ended in', (tester) async {
      final picker = setUpPicker(
        tester,
        lost: (_) => {
          'type': 'media',
          'errorCode': 'no_valid_media_uri',
          'errorMessage': 'Cannot find the selected media.',
        },
      );
      Object? failure;
      unawaited(
        picker.pickPhotos().then(
          (_) {},
          onError: (Object error) => failure = error,
        ),
      );
      await tester.pump();

      excursions.abandon();
      await tester.pump();

      expect(
        failure,
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'no_valid_media_uri',
        ),
      );
    });

    testWidgets('keeps looking while image_picker cannot be asked', (
      tester,
    ) async {
      final picker = setUpPicker(
        tester,
        lost: (look) => switch (look) {
          1 => throw PlatformException(code: 'channel-error'),
          2 => lostImages(['/data/cache/lost.jpg']),
          _ => null,
        },
      );
      PickedFile? photo;
      Object? failure;
      unawaited(
        picker.takePhoto().then(
          (value) => photo = value,
          onError: (Object error) => failure = error,
        ),
      );
      await tester.pump();

      excursions.abandon();
      await tester.pump(PluginAttachmentPicker.lostPickPoll);

      expect(failure, isNull);
      expect(photo?.path, '/data/cache/lost.jpg');
      expect(retrieves(), 2);
    });

    testWidgets(
      'is not looked for on iOS',
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      (tester) async {
        final picker = setUpPicker(
          tester,
          lost: (_) => lostImages(['/data/cache/lost.jpg']),
        );
        var taken = false;
        unawaited(picker.takePhoto().then((_) => taken = true));
        await tester.pump();

        excursions.abandon();
        await tester.pump(PluginAttachmentPicker.lostPickWait);

        expect(calls, ['pickImage']);
        expect(taken, isFalse);
      },
    );
  });
}
