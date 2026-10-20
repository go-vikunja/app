import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/share/share_intent_source.dart';
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
  }) {
    final controller = ShareFilesController(
      source: source,
      files: files,
      uploadsEnabled: enabled,
      maxBytes: maxBytes,
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
}
