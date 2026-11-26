import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/platform/location_removal.dart';
import 'package:vikunja_mobile/core/share/share_intent_source.dart';
import 'package:vikunja_mobile/core/share/share_providers.dart';
import 'package:vikunja_mobile/features/share/application/share_files.dart';

import '../../helpers/attachment_fakes.dart';

void main() {
  SharedFile file(int n, {int? size, String? name}) => SharedFile(
    uri: 'content://f/$n',
    displayName: name ?? 'file-$n.txt',
    size: size,
  );

  ShareFilesController controllerFor(
    FakeShareIntentSource source,
    List<SharedFile> files, {
    bool enabled = true,
    int maxBytes = 100,
    LocationRemoval? locations,
  }) {
    final controller = ShareFilesController(
      source: source,
      share: IncomingShare(files: files),
      uploadsEnabled: enabled,
      maxBytes: maxBytes,
      locations: locations,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  test('copies one file after the other with the limit; a file known to be '
      'too large is not copied', () async {
    final files = [file(1, size: 10), file(2, size: 500), file(3)];
    final source = FakeShareIntentSource(initial: IncomingShare(files: files));
    final controller = controllerFor(source, files);

    expect(controller.preparing, isTrue);
    expect(controller.value[1].status, isA<ShareFileTooLarge>());
    await controller.prepare();

    expect(source.calls, [
      'copy content://f/1 max 100',
      'copy content://f/3 max 100',
    ]);
    expect(controller.preparing, isFalse);
    expect(controller.ready.map((entry) => entry.$2.path), [
      '/cache/share-inbox/1',
      '/cache/share-inbox/2',
    ]);
  });

  test(
    'a copy the source refuses as too large or unreadable says so',
    () async {
      final files = [file(1), file(2)];
      final source = FakeShareIntentSource(initial: IncomingShare(files: files))
        ..copyFailures['content://f/1'] = const SharedFileTooLarge(maxBytes: 7)
        ..copyFailures['content://f/2'] = const SharedFileUnreadable();
      final controller = controllerFor(source, files);

      await controller.prepare();

      expect((controller.value[0].status as ShareFileTooLarge).maxBytes, 7);
      expect(controller.value[1].status, isA<ShareFileUnreadable>());
      expect(controller.ready, isEmpty);
    },
  );

  test('a file removed while another copies is not copied', () async {
    final files = [file(1), file(2)];
    final hold = Completer<void>();
    final source = FakeShareIntentSource(initial: IncomingShare(files: files))
      ..beforeCall = (call) =>
          call.contains('/1 ') ? hold.future : Future.value();
    final controller = controllerFor(source, files);

    final preparing = controller.prepare();
    controller.remove(files[1]);
    hold.complete();
    await preparing;

    expect(source.calls, ['copy content://f/1 max 100']);
    expect(controller.value.map((item) => item.file), [files[0]]);
  });

  test('a file removed while it copies has its copy called off, and the '
      'next file copies without waiting for it', () async {
    final files = [file(1), file(2)];
    final never = Completer<void>();
    final source = FakeShareIntentSource(initial: IncomingShare(files: files))
      ..beforeCall = (call) =>
          call == 'copy content://f/1 max 100' ? never.future : Future.value();
    final controller = controllerFor(source, files);

    final preparing = controller.prepare();
    await pumpEventQueue();
    controller.remove(files[0]);
    await preparing;

    expect(source.calls, [
      'copy content://f/1 max 100',
      'cancelCopy content://f/1',
      'copy content://f/2 max 100',
    ]);
    expect(controller.value.map((item) => item.file), [files[1]]);
    expect(controller.value.single.status, isA<ShareFileReady>());
  });

  test('without attachments on the server nothing is copied; past 20 files '
      'the rest are left out; names are made safe', () async {
    final files = [
      file(0, name: '../../databases/x.db'),
      for (var n = 1; n < 22; n++) file(n),
    ];
    final source = FakeShareIntentSource(initial: IncomingShare(files: files));
    final controller = controllerFor(source, files, enabled: false);

    await controller.prepare();

    expect(source.calls, isEmpty);
    expect(controller.value, hasLength(ShareFilesController.maxFiles));
    expect(controller.leftOut, 2);
    expect(
      controller.value.map((item) => item.status),
      everyElement(isA<ShareFileNotTaken>()),
    );
    expect(controller.value.first.name, '.._.._databases_x.db');
  });

  group('the location', () {
    SharedFile media(int n, String name, String? mimeType) => SharedFile(
      uri: 'content://f/$n',
      displayName: name,
      size: 10,
      mimeType: mimeType,
    );

    test('stopping preparation waits for the current location rewrite '
        'and does not copy the next file', () async {
      final files = [media(1, 'photo.jpg', 'image/jpeg'), file(2)];
      final source = FakeShareIntentSource(
        initial: IncomingShare(files: files),
      );
      final removal = RecordingLocationRemoval();
      final removing = removal.block();
      final controller = controllerFor(source, files, locations: removal);

      unawaited(controller.prepare());
      await pumpEventQueue();
      expect(removal.paths, ['/cache/share-inbox/1']);

      var canClear = false;
      final stopped = controller.stopPreparing().then((_) => canClear = true);
      await pumpEventQueue();
      expect(canClear, isFalse);

      removing.complete();
      await stopped;
      expect(source.calls, ['copy content://f/1 max 100']);
      expect(controller.ready, isEmpty);
    });

    test('goes through the removal for every copy before it is ready, '
        'whatever type the other app gives, so that a photo sent as '
        'application/octet-stream loses it too', () async {
      final files = [
        media(1, 'IMG_1.jpg', 'image/jpeg'),
        media(2, 'clip', 'video/mp4'),
        media(3, 'list.pdf', 'application/pdf'),
        media(4, 'IMG_4.png', null),
        media(5, 'notes', null),
        media(6, 'photo.jpg', 'application/octet-stream'),
      ];
      final source = FakeShareIntentSource(
        initial: IncomingShare(files: files),
      );
      final removal = RecordingLocationRemoval();
      final removing = removal.block();
      final controller = controllerFor(source, files, locations: removal);

      final preparing = controller.prepare();
      await pumpEventQueue();
      expect(removal.paths, ['/cache/share-inbox/1']);
      expect(controller.value.first.status, isA<ShareFilePreparing>());
      expect(controller.ready, isEmpty);

      removing.complete();
      await preparing;

      expect(removal.removed, [
        for (var n = 1; n <= 6; n++) '/cache/share-inbox/$n',
      ]);
      expect(controller.ready, hasLength(6));
    });

    test('stays in a copy it could not be removed from, which is ready '
        'marked for the sheet to say so; the log names no file', () async {
      final files = [
        media(1, 'IMG_1.jpg', 'image/jpeg'),
        media(2, 'IMG_2.jpg', 'image/jpeg'),
      ];
      final source = FakeShareIntentSource(
        initial: IncomingShare(files: files),
      );
      final removal = RecordingLocationRemoval()
        ..failures['/cache/share-inbox/1'] = PlatformException(
          code: 'remove_location_failed',
          message: 'GPS in compressed XMP',
          details: '/cache/share-inbox/1',
        );
      final records = <LogRecord>[];
      final previousLevel = Logger.root.level;
      Logger.root.level = Level.ALL;
      final subscription = Logger.root.onRecord.listen(records.add);
      addTearDown(() async {
        Logger.root.level = previousLevel;
        await subscription.cancel();
      });
      final controller = controllerFor(source, files, locations: removal);

      await controller.prepare();

      expect(
        [
          for (final item in controller.value)
            if (item.status case ShareFileReady(
              :final copy,
              :final keptLocation,
            ))
              (copy.path, keptLocation),
        ],
        [('/cache/share-inbox/1', true), ('/cache/share-inbox/2', false)],
      );
      final record = records.single;
      expect(record.level, Level.WARNING);
      expect(
        record.message,
        'A file keeps its location: PlatformException(remove_location_failed, '
        'GPS in compressed XMP)',
      );
      expect(record.error, isNull);
    });

    testWidgets(
      'is removed on Android only',
      variant: TargetPlatformVariant.all(),
      (tester) async {
        expect(
          ProviderContainer.test().read(shareLocationRemovalProvider),
          defaultTargetPlatform == TargetPlatform.android
              ? isA<PlatformLocationRemoval>()
              : isNull,
        );
      },
    );
  });
}
