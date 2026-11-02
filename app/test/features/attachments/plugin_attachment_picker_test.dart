import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/platform/location_removal.dart';
import 'package:vikunja_mobile/core/security/app_excursions.dart';
import 'package:vikunja_mobile/features/attachments/application/attachment_picker.dart';
import 'package:vikunja_mobile/features/attachments/application/channel_document_picker.dart';
import 'package:vikunja_mobile/features/attachments/application/plugin_attachment_picker.dart';

import '../../helpers/attachment_fakes.dart';

// image_picker's default platform channel, which a test host keeps.
const _imagePicker = MethodChannel('plugins.flutter.io/image_picker');

// image_picker's copies on iOS: a photo's, and a video's with its own name.
const _iosPhoto =
    '/tmp/image_picker_DBEDF48F-39B6-4EA0-A6A5-EE9DA7B93054-55885-00000DCCD9B5CF3F.jpg';
const _iosPng =
    '/tmp/image_picker_F0E0133E-E515-48AF-A7D8-759814A89BCA-55885-00000DCCD9B5D0DD.png';
const _iosVideo =
    '/tmp/image_picker_5B37F082-66DE-4679-A924-C00FBDAD5831-55885-00000DCCD9B5D102IMG_0042.MOV';

// image_picker's copies on Android: the photo picker's in a folder of their
// own, a camera shot's a temporary file.
const _androidPhoto = '/data/cache/5f0c2a/IMG_20261102_101500.jpg';
const _androidVideo = '/data/cache/9a1e7b/VID_20261102_101800.mp4';
const _androidShot = '/data/cache/image_picker1234567890.jpg';

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

  test('several camera shots of one second are numbered', () {
    expect(
      cameraFileName(
        '/tmp/a.PNG',
        takenAt: DateTime(2026, 10, 20, 14, 30, 5),
        number: 2,
      ),
      'IMG_20261020_143005_2.png',
    );
  });

  group('library picks on iOS', () {
    final pickedAt = DateTime(2026, 10, 29, 9, 15, 42);

    test("a photo in image_picker's copy is named like a camera shot", () {
      expect(iosLibraryFileNames(['image_picker_x.jpg'], pickedAt: pickedAt), [
        'image_picker_x.jpg',
      ]);
      expect(
        iosLibraryFileNames([_iosPhoto.split('/').last], pickedAt: pickedAt),
        ['IMG_20261029_091542.jpg'],
      );
    });

    test('several photos of one pick are numbered, and a video keeps its '
        'own name', () {
      expect(
        iosLibraryFileNames([
          for (final path in [_iosPhoto, _iosVideo, _iosPng, '/tmp/a.gif'])
            path.split('/').last,
        ], pickedAt: pickedAt),
        [
          'IMG_20261029_091542_1.jpg',
          'IMG_0042.MOV',
          'IMG_20261029_091542_2.png',
          'a.gif',
        ],
      );
    });

    test('a photo next to a video is not numbered', () {
      expect(
        iosLibraryFileNames([
          _iosVideo.split('/').last,
          _iosPhoto.split('/').last,
        ], pickedAt: pickedAt),
        ['IMG_0042.MOV', 'IMG_20261029_091542.jpg'],
      );
    });
  });

  group('the location of picked photos', () {
    late RecordingLocationRemoval removal;
    late List<LogRecord> records;

    setUp(() {
      removal = RecordingLocationRemoval();
      records = [];
      final previousLevel = Logger.root.level;
      Logger.root.level = Level.ALL;
      final subscription = Logger.root.onRecord.listen(records.add);
      addTearDown(() async {
        Logger.root.level = previousLevel;
        await subscription.cancel();
      });
    });

    void answerPicks(Object? Function(MethodCall call) answer) {
      messenger.setMockMethodCallHandler(
        _imagePicker,
        (call) async => answer(call),
      );
      addTearDown(() => messenger.setMockMethodCallHandler(_imagePicker, null));
    }

    PluginAttachmentPicker picker() => PluginAttachmentPicker(
      locations: removal,
      now: () => DateTime(2026, 10, 29, 9, 15, 42),
    );

    testWidgets(
      'is removed from every photo and video before they are handed on',
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      (tester) async {
        answerPicks((_) => [_iosPhoto, _iosVideo]);
        final removing = removal.block();
        List<PickedFile>? files;
        List<String>? removedBefore;
        unawaited(
          picker().pickPhotos().then((value) {
            files = value;
            removedBefore = [...removal.removed];
          }),
        );
        await tester.pump();
        expect(removal.paths, [_iosPhoto]);
        expect(files, isNull);

        removing.complete();
        await tester.pump();

        expect(removedBefore, [_iosPhoto, _iosVideo]);
        expect(files?.map((file) => (file.path, file.name, file.mimeType)), [
          (_iosPhoto, 'IMG_20261029_091542.jpg', 'image/jpeg'),
          (_iosVideo, 'IMG_0042.MOV', 'video/quicktime'),
        ]);
      },
    );

    testWidgets(
      'is removed from a camera shot',
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      (tester) async {
        answerPicks((_) => _iosPhoto);
        final removing = removal.block();
        var taken = false;
        PickedFile? photo;
        List<String>? removedBefore;
        unawaited(
          picker().takePhoto().then((value) {
            taken = true;
            photo = value;
            removedBefore = [...removal.removed];
          }),
        );
        await tester.pump();
        expect(removal.paths, [_iosPhoto]);
        expect(taken, isFalse);

        removing.complete();
        await tester.pump();

        expect(removedBefore, [_iosPhoto]);
        expect(photo?.name, 'IMG_20261029_091542.jpg');
      },
    );

    testWidgets(
      'stays in a file it could not be removed from, which is still handed '
      'on; the log names no file',
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      (tester) async {
        answerPicks((_) => [_iosPhoto]);
        removal.failures[_iosPhoto] = PlatformException(
          code: 'remove_location_failed',
          message: 'Failure',
          details: _iosPhoto,
        );

        final files = await picker().pickPhotos(imagesOnly: true);

        expect(files.single.path, _iosPhoto);
        expect(files.single.name, 'IMG_20261029_091542.jpg');
        final record = records.single;
        expect(record.level, Level.WARNING);
        expect(record.message, contains('PlatformException'));
        expect(record.message, isNot(contains('image_picker')));
        expect(record.message, isNot(contains('IMG_')));
        expect(record.error, isNull);
      },
    );

    testWidgets(
      'stays only in a file it could not be removed from, and is removed '
      'from the files after it',
      variant: TargetPlatformVariant.only(TargetPlatform.android),
      (tester) async {
        answerPicks((_) => [_androidPhoto, _androidVideo, _androidShot]);
        removal.failures[_androidPhoto] = PlatformException(
          code: 'remove_location_failed',
          message: 'GPS in compressed XMP',
        );

        final files = await picker().pickPhotos();

        expect(removal.paths, [_androidPhoto, _androidVideo, _androidShot]);
        expect(removal.removed, [_androidVideo, _androidShot]);
        expect(files.map((file) => file.path), [
          _androidPhoto,
          _androidVideo,
          _androidShot,
        ]);
      },
    );

    testWidgets(
      'stays in a file whose removal fails unexpectedly; the log names only '
      'the type of the failure',
      variant: TargetPlatformVariant.only(TargetPlatform.android),
      (tester) async {
        answerPicks((_) => [_androidPhoto]);
        removal.failures[_androidPhoto] = MissingPluginException(
          'No implementation found for method removeLocation: $_androidPhoto',
        );

        final files = await picker().pickPhotos();

        expect(files.single.path, _androidPhoto);
        expect(
          records.single.message,
          'A file keeps its location: MissingPluginException',
        );
      },
    );

    testWidgets(
      'and the names are left to the photo picker on Android',
      variant: TargetPlatformVariant.only(TargetPlatform.android),
      (tester) async {
        answerPicks((_) => [_iosPhoto]);

        final files = await PluginAttachmentPicker().pickPhotos();

        expect(files.single.name, _iosPhoto.split('/').last);
      },
    );

    testWidgets(
      'is removed on Android too, from photos and videos of the photo picker '
      'and from camera shots, before they are handed on',
      variant: TargetPlatformVariant.only(TargetPlatform.android),
      (tester) async {
        answerPicks(
          (call) => call.method == 'pickImage'
              ? _androidShot
              : [_androidPhoto, _androidVideo],
        );
        final removing = removal.block();
        List<PickedFile>? files;
        unawaited(picker().pickPhotos().then((value) => files = value));
        await tester.pump();
        expect(removal.paths, [_androidPhoto]);
        expect(files, isNull);

        removing.complete();
        await tester.pump();

        expect(removal.removed, [_androidPhoto, _androidVideo]);
        expect(files?.map((file) => (file.path, file.name, file.mimeType)), [
          (_androidPhoto, 'IMG_20261102_101500.jpg', 'image/jpeg'),
          (_androidVideo, 'VID_20261102_101800.mp4', 'video/mp4'),
        ]);

        final shot = await picker().takePhoto();

        expect(removal.removed.last, _androidShot);
        expect(shot?.path, _androidShot);
      },
    );

    testWidgets(
      'stays in files from the file picker',
      variant: const TargetPlatformVariant({
        TargetPlatform.iOS,
        TargetPlatform.android,
      }),
      (tester) async {
        final android = defaultTargetPlatform == TargetPlatform.android;
        final channel = android
            ? const MethodChannel(ChannelDocumentPicker.channelName)
            : const MethodChannel('plugins.flutter.io/file_selector');
        messenger.setMockMethodCallHandler(
          channel,
          (call) async => switch (call.method) {
            'pick' => [
              {
                'uri': 'content://media/1',
                'name': 'IMG_0042.jpg',
                'size': 10,
                'mime': 'image/jpeg',
              },
            ],
            'copy' => {'path': '/data/cache/picked/IMG_0042.jpg', 'size': 10},
            _ => ['/tmp/IMG_0042.jpg'],
          },
        );
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

        final picked = await PluginAttachmentPicker(
          documents: android ? ChannelDocumentPicker() : null,
          locations: removal,
        ).pickFiles(maxBytes: 100, imagesOnly: true);

        expect(picked.files.single.name, 'IMG_0042.jpg');
        expect(removal.paths, isEmpty);
      },
    );

    testWidgets(
      'is removed by the app on Android and iOS only',
      variant: const TargetPlatformVariant({
        TargetPlatform.iOS,
        TargetPlatform.android,
        TargetPlatform.macOS,
      }),
      (tester) async {
        final container = ProviderContainer.test();

        final picker =
            container.read(attachmentPickerProvider) as PluginAttachmentPicker;

        expect(
          picker.locations,
          defaultTargetPlatform == TargetPlatform.macOS
              ? isNull
              : isA<PlatformLocationRemoval>(),
        );
      },
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
