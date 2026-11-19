import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/attachments/attachment_images.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/attachments/application/attachment_picker.dart';
import 'package:vikunja_mobile/features/description_editor/application/editor_protocol.dart';
import 'package:vikunja_mobile/features/description_editor/presentation/description_editor_page.dart';

import '../../helpers/attachment_picker_fake.dart';
import '../../helpers/auth_fakes.dart';
import '../../helpers/editor_bridge_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

const int _mib = 1024 * 1024;

void main() {
  final now = DateTime(2026, 10, 10, 12);
  const photo = PickedFile(
    path: '/cache/IMG_1.jpg',
    name: 'IMG_1.jpg',
    mimeType: 'image/jpeg',
  );
  late SyncFakes data;
  late FakeEditorBridges bridges;
  late FakeAttachmentPicker picker;

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [
      sampleProject(id: 1, title: 'Work'),
      sampleProject(id: 2, title: 'Old', archived: true),
    ];
    data.tasks.all = [
      sampleTask(id: 1, title: 'Quarterly report', description: '<p>a</p>'),
      sampleTask(id: 3, title: 'Archived', projectId: 2),
      const Task(id: -1, title: 'Fresh task', projectId: 1),
    ];
    bridges = FakeEditorBridges();
    picker = FakeAttachmentPicker()..photos = [photo];
  });

  Future<void> openEditor(WidgetTester tester, {String? route}) async {
    usePhoneSurface(tester);
    await pumpSignedInApp(
      tester,
      sync: data,
      auth: AuthFakes(),
      now: now,
      overrides: [bridges.override, picker.providerOverride],
    );
    unawaited(
      containerOf(tester)
          .read(appRouterProvider)
          .push<bool>(route ?? AppRoutes.taskDescription(1)),
    );
    await tester.pumpAndSettle();
  }

  Finder imageButton() => find.byTooltip(en.editorImage);

  Future<void> insertFrom(
    WidgetTester tester,
    String source, {
    bool settle = true,
  }) async {
    await tester.ensureVisible(imageButton());
    await tester.pumpAndSettle();
    await tester.tap(imageButton());
    await tester.pumpAndSettle();
    await tester.tap(find.text(source).last);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
  }

  /// Out of the way of the toolbar it would cover.
  Future<void> dismissMessage(WidgetTester tester) async {
    ScaffoldMessenger.of(tester.element(find.byType(SnackBar)))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
  }

  bool saveEnabled(WidgetTester tester) =>
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, en.taskEditSave))
          .onPressed !=
      null;

  testWidgets("the page's images get their previews from the app, once "
      'each', (tester) async {
    await openEditor(tester);
    final bridge = bridges.last;
    final apiRoot = bridge.init!.links.apiRoot;
    final image = '$apiRoot/tasks/1/attachments/9';
    data.attachmentImages.images[(
      1,
      9,
      AttachmentPreviewSize.extraLarge,
    )] = AttachmentImage(
      bytes: Uint8List.fromList([1, 2, 3]),
      contentType: 'image/jpeg',
    );

    bridge.emit(EditorImagesWanted([image]));
    await tester.pumpAndSettle();
    bridge.emit(EditorImagesWanted([image]));
    await tester.pumpAndSettle();

    expect(bridge.imagePreviews, [
      {image: 'data:image/jpeg;base64,AQID'},
    ]);
  });

  testWidgets('a photo is uploaded to the task, then inserted the way the '
      'web writes it', (tester) async {
    await openEditor(tester);

    await insertFrom(tester, en.attachmentSourcePhotos);

    expect(picker.calls, ['photos images single']);
    expect(data.attachments.calls, ['uploadNow 1 IMG_1.jpg']);
    expect(
      bridges.last.commands.last,
      EditorCommand.insertImage(
        src: 'https://tasks.example.org/vikunja/api/v2/tasks/1/attachments/500',
        id: 'tiptap-image-1-500',
      ),
    );
    expect(tester.takeAnnouncements(), [
      isAccessibilityAnnouncement(en.editorImageInserted),
    ]);
  });

  testWidgets('an image whose location could not be removed is uploaded '
      'only when the user says so', (tester) async {
    picker.photos = [
      const PickedFile(
        path: '/cache/IMG_2.jpg',
        name: 'IMG_2.jpg',
        mimeType: 'image/jpeg',
        keptLocation: true,
      ),
    ];
    await openEditor(tester);

    await insertFrom(tester, en.attachmentSourcePhotos);
    expect(find.text(en.attachmentLocationKeptTitle), findsOneWidget);
    await tester.tap(find.text(en.attachmentLocationKeptSkip));
    await tester.pumpAndSettle();
    expect(data.attachments.calls, isEmpty);

    await insertFrom(tester, en.attachmentSourcePhotos);
    await tester.tap(find.text(en.attachmentLocationKeptUpload));
    await tester.pumpAndSettle();
    expect(data.attachments.calls, ['uploadNow 1 IMG_2.jpg']);
  });

  testWidgets('the camera and files give one image each', (tester) async {
    picker
      ..camera = photo
      ..files = [photo];
    await openEditor(tester);

    await insertFrom(tester, en.attachmentSourceCamera);
    await insertFrom(tester, en.attachmentSourceFiles);

    expect(picker.calls, ['camera', 'files images single']);
    expect(
      bridges.last.commands.where(
        (command) => command.name == EditorCommandName.insertImage,
      ),
      hasLength(2),
    );
  });

  testWidgets('while the image uploads a progress line shows and Save '
      'waits; leaving cancels the upload', (tester) async {
    final upload = Completer<void>();
    data.attachments.beforeCall = (_) => upload.future;
    await openEditor(tester);
    bridges.last.edit('<p>a b</p>');
    await tester.pump();
    expect(saveEnabled(tester), isTrue);

    await insertFrom(tester, en.attachmentSourcePhotos, settle: false);

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(LinearProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(en.editorImageUploading), findsOneWidget);
    expect(saveEnabled(tester), isFalse);

    upload.complete();
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(saveEnabled(tester), isTrue);
    expect(data.attachments.cancelTokens.single?.isCancelled, isFalse);
  });

  testWidgets('Save in the leave dialog waits for the upload, saving '
      'meanwhile, and saves the description with the image', (tester) async {
    const src =
        'https://tasks.example.org/vikunja/api/v2/tasks/1/attachments/500';
    const image = '<img data-src="$src" src="#" id="tiptap-image-1-500">';
    final upload = Completer<void>();
    data.attachments.beforeCall = (_) => upload.future;
    await openEditor(tester);
    final bridge = bridges.last..edit('<p>a b</p>');
    bridge.onCommand = (command) {
      if (command.name == EditorCommandName.insertImage) {
        bridge.edit('<p>a b</p>$image');
      }
    };
    await tester.pump();
    await insertFrom(tester, en.attachmentSourcePhotos, settle: false);

    await tester.pageBack();
    await pumpFrames(tester, 5);
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text(en.taskEditSave),
      ),
    );
    await pumpFrames(tester, 5);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(data.tasks.descriptionUpdates, isEmpty);
    expect(bridge.readOnly, isEmpty);

    upload.complete();
    await tester.pumpAndSettle();

    expect(data.tasks.descriptionUpdates, [
      (1, '<p>a b</p>$image', '<p>a</p>'),
    ]);
    expect(data.attachments.cancelTokens.single?.isCancelled, isFalse);
    expect(find.byType(DescriptionEditorPage), findsNothing);
  });

  testWidgets('Back while Save waits for the upload stops it: the '
      'description is saved without the image, and the page says so', (
    tester,
  ) async {
    data.attachments.beforeCall = (_) async {
      await data.attachments.cancelTokens.last!.whenCancel;
      throw const NetworkFailure(NetworkProblem.unreachable);
    };
    await openEditor(tester);
    final bridge = bridges.last..edit('<p>a b</p>');
    await tester.pump();
    await insertFrom(tester, en.attachmentSourcePhotos, settle: false);
    await tester.pageBack();
    await pumpFrames(tester, 5);
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text(en.taskEditSave),
      ),
    );
    await pumpFrames(tester, 5);
    expect(data.tasks.descriptionUpdates, isEmpty);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(data.attachments.cancelTokens.single?.isCancelled, isTrue);
    expect(find.text(en.editorImageNotAdded), findsOneWidget);
    expect(data.tasks.descriptionUpdates, [(1, '<p>a b</p>', '<p>a</p>')]);
    expect(
      bridge.commands.where(
        (command) => command.name == EditorCommandName.insertImage,
      ),
      isEmpty,
    );
    expect(find.byType(DescriptionEditorPage), findsNothing);
  });

  testWidgets('a refused upload says why and inserts nothing', (tester) async {
    await openEditor(tester);

    data.attachments.failure = const FileTooLarge(code: 4012);
    await insertFrom(tester, en.attachmentSourcePhotos);
    expect(find.text(en.attachmentFileTooLarge), findsOneWidget);
    await dismissMessage(tester);

    data.attachments.failure = const NetworkFailure(NetworkProblem.unreachable);
    await insertFrom(tester, en.attachmentSourcePhotos);
    expect(find.text(en.attachmentNeedsConnection), findsOneWidget);
    await dismissMessage(tester);

    data.attachments
      ..failure = null
      ..uploadSizes[photo.path] = 30 * _mib;
    await insertFrom(tester, en.attachmentSourcePhotos);
    expect(find.text(en.attachmentFileTooLargeLimit('20 MB')), findsOneWidget);

    expect(
      bridges.last.commands.map((command) => command.name),
      isNot(contains(EditorCommandName.insertImage)),
    );
  });

  testWidgets('an image the document picker left uncopied as too large is '
      'refused with the limit', (tester) async {
    picker.tooLargeFiles = ['huge.png'];
    await openEditor(tester);

    await insertFrom(tester, en.attachmentSourceFiles);

    expect(picker.maxBytes, [20 * _mib]);
    expect(find.text(en.attachmentFileTooLargeLimit('20 MB')), findsOneWidget);
    expect(data.attachments.calls, isEmpty);
  });

  testWidgets("the picker's copy goes once the upload is done, whether it "
      'went or not', (tester) async {
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('editor_image_test'),
    ))!;
    addTearDown(() => directory.deleteSync(recursive: true));
    File pickedCopy(String name) =>
        File('${directory.path}/$name')..writeAsBytesSync(const [1, 2, 3]);
    Future<void> settleFiles() => tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    final sent = pickedCopy('sent.jpg');
    final refused = pickedCopy('refused.jpg');
    await openEditor(tester);

    picker.photos = [PickedFile(path: sent.path, name: 'sent.jpg')];
    await insertFrom(tester, en.attachmentSourcePhotos);
    await settleFiles();
    expect(data.attachments.calls, ['uploadNow 1 sent.jpg']);
    expect(sent.existsSync(), isFalse);

    data.attachments.failure = const NetworkFailure(NetworkProblem.unreachable);
    picker.photos = [PickedFile(path: refused.path, name: 'refused.jpg')];
    await insertFrom(tester, en.attachmentSourcePhotos);
    await settleFiles();
    expect(refused.existsSync(), isFalse);
  });

  testWidgets('a cancelled pick or a picker that cannot open inserts '
      'nothing', (tester) async {
    picker.photos = [];
    await openEditor(tester);

    await insertFrom(tester, en.attachmentSourcePhotos);
    expect(data.attachments.calls, isEmpty);

    picker.failure = Exception('denied');
    await insertFrom(tester, en.attachmentSourcePhotos);
    expect(find.text(en.attachmentPickFailed), findsOneWidget);
    expect(data.attachments.calls, isEmpty);
  });

  group('no image button', () {
    testWidgets('offline', (tester) async {
      await openEditor(tester);
      expect(imageButton(), findsOneWidget);

      data.engine.emit(
        SyncFailed(
          failure: const NetworkFailure(NetworkProblem.unreachable),
          lastSyncedAt: now,
        ),
      );
      await tester.pumpAndSettle();
      expect(imageButton(), findsNothing);
    });

    testWidgets('for a task whose create is still queued', (tester) async {
      await openEditor(tester, route: AppRoutes.taskDescription(-1));
      expect(imageButton(), findsNothing);
    });

    testWidgets('in an archived project', (tester) async {
      await openEditor(tester, route: AppRoutes.taskDescription(3));
      expect(imageButton(), findsNothing);
    });

    testWidgets("for a project's description", (tester) async {
      await openEditor(tester, route: AppRoutes.projectDescription(1));
      expect(imageButton(), findsNothing);
    });

    testWidgets('with attachments off on the server', (tester) async {
      data.attachments.uploadsEnabled = false;
      await openEditor(tester);
      expect(imageButton(), findsNothing);
    });
  });
}
