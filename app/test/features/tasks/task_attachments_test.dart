import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/attachments/pending_upload.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/attachments/application/attachment_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/rich_text/attachment_image_viewer.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../../helpers/attachment_picker_fake.dart';
import '../../helpers/auth_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';
import '../../helpers/task_details_fakes.dart';

const int _mib = 1024 * 1024;

void main() {
  final now = DateTime(2026, 10, 12, 12);
  late SyncFakes data;
  late FakeAttachmentPicker picker;

  final photo = sampleAttachment(id: 3, taskId: 4, size: 1536);
  final pdf = sampleAttachment(
    id: 5,
    taskId: 4,
    name: 'notes.pdf',
    mime: 'application/pdf',
    size: 1500000,
  );

  setUp(() {
    picker = FakeAttachmentPicker();
    data = SyncFakes(now: now);
    data.projects.all = [
      sampleProject(id: 1, title: 'Work', identifier: 'WORK'),
      sampleProject(id: 2, title: 'Old', archived: true),
    ];
    data.tasks.all = [
      sampleTask(id: 4, title: 'Ship the order'),
      sampleTask(id: 6, title: 'Archived task', projectId: 2),
      const Task(id: -1, title: 'Fresh task', projectId: 1),
    ];
    data.details.detailsByTask[4] = TaskDetails(attachments: [photo, pdf]);
    data.attachmentImages.fallback = samplePngImage;
  });

  Finder sheet() => find.byType(TaskDetailSheet).last;

  Finder inSheet(Finder matching) =>
      find.descendant(of: sheet(), matching: matching);

  Future<void> openDetail(WidgetTester tester, Task task) async {
    usePhoneSurface(tester, logicalSize: const Size(360, 2400));
    final auth = AuthFakes();
    await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
    );
    await pumpVikunjaApp(
      tester,
      auth: auth,
      sync: data,
      overrides: [
        clockProvider.overrideWithValue(() => now),
        picker.providerOverride,
      ],
    );
    final context = containerOf(tester)
        .read(appRouterProvider)
        .routerDelegate
        .navigatorKey
        .currentContext!;
    unawaited(showTaskDetail(context, task: task));
    await tester.pumpAndSettle();
  }

  Future<void> add(WidgetTester tester, String source) async {
    await tester.tap(inSheet(find.byTooltip(en.attachmentAdd)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(source).last);
    await tester.pumpAndSettle();
  }

  Future<void> choose(
    WidgetTester tester,
    TaskAttachment attachment,
    String action,
  ) async {
    await tester.tap(
      inSheet(find.byTooltip(en.attachmentOptions(attachment.name))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(action).last);
    await tester.pumpAndSettle();
  }

  Future<List<String>> menuOf(
    WidgetTester tester,
    TaskAttachment attachment,
  ) async {
    await tester.tap(
      inSheet(find.byTooltip(en.attachmentOptions(attachment.name))),
    );
    await tester.pumpAndSettle();
    final labels = [
      for (final item in tester.widgetList<PopupMenuItem<Object?>>(
        find.byWidgetPredicate((widget) => widget is PopupMenuItem),
      ))
        tester
            .widget<Text>(
              find.descendant(
                of: find.byWidget(item),
                matching: find.byType(Text),
              ),
            )
            .data!,
    ];
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    return labels;
  }

  group('adding files', () {
    testWidgets('Files queues one upload per file; each shows as a waiting '
        'row', (tester) async {
      picker.files = const [
        PickedFile(path: '/cache/a.pdf', name: 'a.pdf', mimeType: 'x/y'),
        PickedFile(path: '/cache/b.txt', name: 'b.txt'),
      ];
      data.tasks.uploadSizes['/cache/a.pdf'] = 2048;
      await openDetail(tester, data.tasks.find(4)!);

      await add(tester, en.attachmentSourceFiles);

      expect(picker.calls, ['files']);
      expect(data.tasks.uploadRequests, [
        (
          taskId: 4,
          sourcePath: '/cache/a.pdf',
          fileName: 'a.pdf',
          mimeType: 'x/y',
          moveSource: true,
        ),
        (
          taskId: 4,
          sourcePath: '/cache/b.txt',
          fileName: 'b.txt',
          mimeType: null,
          moveSource: true,
        ),
      ]);
      expect(inSheet(find.text('a.pdf')), findsOneWidget);
      expect(
        inSheet(find.text('${en.attachmentWaiting} · 2 KB')),
        findsOneWidget,
      );
      expect(find.text(en.attachmentsQueued(2)), findsOneWidget);
    });

    testWidgets('Photos and the camera use their pickers', (tester) async {
      picker
        ..photos = const [PickedFile(path: '/cache/p.jpg', name: 'p.jpg')]
        ..camera = const PickedFile(path: '/cache/c.jpg', name: 'c.jpg');
      await openDetail(tester, data.tasks.find(4)!);

      await add(tester, en.attachmentSourcePhotos);
      await add(tester, en.attachmentSourceCamera);

      expect(picker.calls, ['photos', 'camera']);
      expect(data.tasks.writes, [
        'queueUpload 4 p.jpg move',
        'queueUpload 4 c.jpg move',
      ]);
      expect(inSheet(find.text('p.jpg')), findsOneWidget);
      expect(inSheet(find.text('c.jpg')), findsOneWidget);
    });

    testWidgets("a file above the server's limit is refused with the limit; "
        'the others go', (tester) async {
      picker.files = const [
        PickedFile(path: '/cache/big.mov', name: 'big.mov'),
        PickedFile(path: '/cache/small.txt', name: 'small.txt'),
      ];
      data.tasks.uploadSizes['/cache/big.mov'] = 30 * _mib;
      await openDetail(tester, data.tasks.find(4)!);

      await add(tester, en.attachmentSourceFiles);

      expect(data.tasks.pendingUploads.map((upload) => upload.fileName), [
        'small.txt',
      ]);
      expect(
        find.text(
          '${en.attachmentsQueued(1)} '
          '${en.attachmentTooLarge('big.mov', '20 MB')}',
        ),
        findsOneWidget,
      );
      expect(inSheet(find.text('big.mov')), findsNothing);
    });

    testWidgets('files the document picker left uncopied as too large are '
        'named with the limit', (tester) async {
      picker
        ..files = const [PickedFile(path: '/cache/a.txt', name: 'a.txt')]
        ..tooLargeFiles = ['huge.mov'];
      await openDetail(tester, data.tasks.find(4)!);

      await add(tester, en.attachmentSourceFiles);

      expect(picker.maxBytes, [20 * _mib]);
      expect(data.tasks.writes, ['queueUpload 4 a.txt move']);
      expect(
        find.text(
          '${en.attachmentsQueued(1)} '
          '${en.attachmentTooLarge('huge.mov', '20 MB')}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a cancelled picker changes nothing; one that cannot open '
        'says so', (tester) async {
      await openDetail(tester, data.tasks.find(4)!);

      await add(tester, en.attachmentSourceFiles);
      expect(data.tasks.writes, isEmpty);
      expect(find.byType(SnackBar), findsNothing);

      picker.failure = Exception('no camera');
      await add(tester, en.attachmentSourceCamera);
      expect(find.text(en.attachmentPickFailed), findsOneWidget);
      expect(data.tasks.writes, isEmpty);
    });

    testWidgets('offline the section still takes files, which wait', (
      tester,
    ) async {
      data.details.detailsFailure = const NetworkFailure(
        NetworkProblem.unreachable,
      );
      picker.files = const [PickedFile(path: '/cache/a.pdf', name: 'a.pdf')];
      await openDetail(tester, data.tasks.find(4)!);

      expect(inSheet(find.text(en.taskDetailAttachments)), findsOneWidget);
      expect(inSheet(find.text('photo.png')), findsNothing);
      await add(tester, en.attachmentSourceFiles);

      expect(data.tasks.writes, ['queueUpload 4 a.pdf move']);
      expect(
        inSheet(find.textContaining(en.attachmentWaiting)),
        findsOneWidget,
      );
    });

    testWidgets('a task whose create is still queued takes files too', (
      tester,
    ) async {
      picker.files = const [PickedFile(path: '/cache/a.pdf', name: 'a.pdf')];
      await openDetail(tester, data.tasks.find(-1)!);

      await add(tester, en.attachmentSourceFiles);

      expect(data.tasks.writes, ['queueUpload -1 a.pdf move']);
      expect(inSheet(find.text('a.pdf')), findsOneWidget);
      expect(data.details.calls, isEmpty);
    });
  });

  group('queued uploads', () {
    testWidgets('one on its way shows an indeterminate progress, a refused '
        'one says why; Cancel drops it', (tester) async {
      await openDetail(tester, data.tasks.find(4)!);
      final id = await data.tasks.queueUpload(
        4,
        sourcePath: '/cache/scan.pdf',
        fileName: 'scan.pdf',
      );
      await tester.pumpAndSettle();

      data.tasks.setUploadState(id!, PendingUploadState.sending);
      await tester.pump();
      await tester.pump();
      expect(inSheet(find.textContaining(en.attachmentUploading)), findsOne);
      expect(inSheet(find.byType(LinearProgressIndicator)), findsOneWidget);

      data.tasks.setUploadState(
        id,
        PendingUploadState.failed,
        failure: const FileTooLarge(code: 4012),
      );
      await tester.pump();
      await tester.pump();
      expect(
        inSheet(find.textContaining(en.attachmentUploadTooLarge)),
        findsOneWidget,
      );
      data.tasks.setUploadState(
        id,
        PendingUploadState.failed,
        failure: const Forbidden(code: 1),
      );
      await tester.pump();
      await tester.pump();
      expect(
        inSheet(find.textContaining(en.attachmentUploadFailed)),
        findsOneWidget,
      );

      await tester.tap(
        inSheet(find.byTooltip(en.attachmentCancelUpload('scan.pdf'))),
      );
      await tester.pumpAndSettle();
      expect(data.tasks.writes.last, 'cancelUpload $id');
      expect(inSheet(find.text('scan.pdf')), findsNothing);
    });

    testWidgets('a finished upload joins the list without a read', (
      tester,
    ) async {
      await openDetail(tester, data.tasks.find(4)!);
      final id = await data.tasks.queueUpload(
        4,
        sourcePath: '/cache/scan.pdf',
        fileName: 'scan.pdf',
      );
      await tester.pumpAndSettle();

      data.tasks.completeUpload(
        id!,
        const TaskAttachment(
          id: 9,
          taskId: 4,
          name: 'scan.pdf',
          mime: 'application/pdf',
          size: 4096,
        ),
      );
      await tester.pumpAndSettle();

      expect(data.details.calls, ['details 4']);
      expect(inSheet(find.text('scan.pdf')), findsOneWidget);
      expect(inSheet(find.text('4 KB')), findsOneWidget);
      expect(
        inSheet(find.byTooltip(en.attachmentOptions('scan.pdf'))),
        findsOneWidget,
      );
    });
  });

  group('the menu', () {
    testWidgets('an image opens in the viewer, another file in another app', (
      tester,
    ) async {
      await openDetail(tester, data.tasks.find(4)!);

      await tester.tap(inSheet(find.text('notes.pdf')));
      await tester.pumpAndSettle();
      expect(data.attachments.calls, ['download 4 5']);
      expect(data.fileActions.calls, [
        'openWith /cache/attachments/4/5/notes.pdf application/pdf',
      ]);

      await choose(tester, photo, en.attachmentOpen);
      expect(find.byType(AttachmentImageViewer), findsOneWidget);
      expect(data.attachments.calls, ['download 4 5']);
    });

    testWidgets('a file no app can open says so', (tester) async {
      data.fileActions.canOpen = false;
      await openDetail(tester, data.tasks.find(4)!);

      await choose(tester, pdf, en.attachmentOpen);

      expect(find.text(en.attachmentNoApp), findsOneWidget);
    });

    testWidgets('Share and Save hand the downloaded file on, anchored at the '
        'row', (tester) async {
      await openDetail(tester, data.tasks.find(4)!);

      await choose(tester, pdf, en.attachmentShare);
      await choose(tester, pdf, en.attachmentSaveToDevice);

      const path = '/cache/attachments/4/5/notes.pdf';
      expect(data.fileActions.calls, [
        'share $path notes.pdf application/pdf',
        'saveAs $path notes.pdf application/pdf',
      ]);
      expect(data.fileActions.origins, everyElement(isNotNull));
      expect(find.text(en.attachmentSaved), findsOneWidget);
    });

    testWidgets('a cancelled save says nothing; a failed download says why', (
      tester,
    ) async {
      data.fileActions.saveConfirmed = false;
      await openDetail(tester, data.tasks.find(4)!);

      await choose(tester, pdf, en.attachmentSaveToDevice);
      expect(find.byType(SnackBar), findsNothing);

      data.attachments.failure = const NetworkFailure(
        NetworkProblem.unreachable,
      );
      await choose(tester, pdf, en.attachmentShare);
      expect(find.text(en.attachmentNeedsConnection), findsOneWidget);
      expect(data.fileActions.calls, hasLength(1));
    });

    testWidgets('the row says it is downloading and takes no taps meanwhile', (
      tester,
    ) async {
      final download = Completer<void>();
      data.attachments.beforeCall = (_) => download.future;
      await openDetail(tester, data.tasks.find(4)!);

      await tester.tap(inSheet(find.text('notes.pdf')));
      await tester.pump();
      expect(inSheet(find.text(en.attachmentDownloading)), findsOneWidget);
      await tester.tap(inSheet(find.text('notes.pdf')));
      await tester.pump();
      expect(data.attachments.calls, ['download 4 5']);

      download.complete();
      await tester.pumpAndSettle();
      expect(inSheet(find.text(en.attachmentDownloading)), findsNothing);
      expect(data.fileActions.calls, hasLength(1));
    });

    testWidgets('a download can be cancelled from its row, silently', (
      tester,
    ) async {
      final download = Completer<void>();
      data.attachments.beforeCall = (_) => download.future;
      await openDetail(tester, data.tasks.find(4)!);

      await choose(tester, pdf, en.attachmentShare);
      await tester.tap(
        inSheet(find.byTooltip(en.attachmentCancelDownload('notes.pdf'))),
      );
      await tester.pump();
      expect(data.attachments.cancelTokens.single!.isCancelled, isTrue);

      download.completeError(Exception('cancelled'));
      await tester.pumpAndSettle();
      expect(inSheet(find.text(en.attachmentDownloading)), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(data.fileActions.calls, isEmpty);
    });

    testWidgets('closing the sheet cancels a download', (tester) async {
      final download = Completer<void>();
      data.attachments.beforeCall = (_) => download.future;
      await openDetail(tester, data.tasks.find(4)!);

      await tester.tap(inSheet(find.text('notes.pdf')));
      await tester.pump();
      await tester.tap(inSheet(find.byTooltip(en.taskDetailClose)));
      await tester.pumpAndSettle();

      expect(data.attachments.cancelTokens.single!.isCancelled, isTrue);
      download.complete();
      await tester.pumpAndSettle();
      expect(data.fileActions.calls, isEmpty);
    });

    testWidgets('a delete or a cover change says so on the row, not that it '
        'downloads', (tester) async {
      final change = Completer<void>();
      data.attachments.beforeCall = (_) => change.future;
      await openDetail(tester, data.tasks.find(4)!);

      await tester.tap(
        inSheet(find.byTooltip(en.attachmentOptions(photo.name))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.attachmentMakeCover).last);
      await tester.pump(const Duration(milliseconds: 500));
      expect(inSheet(find.text(en.attachmentSaving)), findsOneWidget);
      expect(inSheet(find.text(en.attachmentDownloading)), findsNothing);
      expect(
        inSheet(find.byTooltip(en.attachmentCancelDownload('photo.png'))),
        findsNothing,
      );

      change.complete();
      await tester.pumpAndSettle();

      final deletion = Completer<void>();
      data.attachments.beforeCall = (_) => deletion.future;
      await choose(tester, pdf, en.attachmentDelete);
      await tester.tap(find.text(en.attachmentDeleteConfirm));
      await tester.pump(const Duration(milliseconds: 500));
      expect(inSheet(find.text(en.attachmentDeleting)), findsOneWidget);

      deletion.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('an image can become the cover and stop being it', (
      tester,
    ) async {
      await openDetail(tester, data.tasks.find(4)!);
      expect(inSheet(find.text(en.taskDetailCoverImage)), findsNothing);
      expect(await menuOf(tester, pdf), [
        en.attachmentOpen,
        en.attachmentShare,
        en.attachmentSaveToDevice,
        en.attachmentDelete,
      ]);

      data.details.detailsByTask[4] = TaskDetails(
        attachments: [photo, pdf],
        coverImageAttachmentId: 3,
      );
      await choose(tester, photo, en.attachmentMakeCover);
      expect(data.attachments.calls, ['setCover 4 3']);
      expect(inSheet(find.text(en.taskDetailCoverImage)), findsOneWidget);
      expect(find.text(en.attachmentCoverSet), findsOneWidget);
      expect(data.details.calls, ['details 4', 'details 4']);

      data.details.detailsByTask[4] = TaskDetails(attachments: [photo, pdf]);
      await choose(tester, photo, en.attachmentRemoveCover);
      expect(data.attachments.calls, ['setCover 4 3', 'setCover 4 null']);
      expect(inSheet(find.text(en.taskDetailCoverImage)), findsNothing);
      expect(find.text(en.attachmentCoverRemoved), findsOneWidget);
    });

    testWidgets("Delete asks with the web's words; the cover is cleared with "
        'it', (tester) async {
      data.details.detailsByTask[4] = TaskDetails(
        attachments: [photo, pdf],
        coverImageAttachmentId: 3,
      );
      await openDetail(tester, data.tasks.find(4)!);

      await choose(tester, pdf, en.attachmentDelete);
      expect(find.text(en.attachmentDeleteBody('notes.pdf')), findsOneWidget);
      await tester.tap(find.text(en.cancel));
      await tester.pumpAndSettle();
      expect(data.attachments.calls, isEmpty);

      data.details.detailsByTask[4] = TaskDetails(
        attachments: [photo],
        coverImageAttachmentId: 3,
      );
      await choose(tester, pdf, en.attachmentDelete);
      await tester.tap(find.text(en.attachmentDeleteConfirm));
      await tester.pumpAndSettle();
      expect(data.attachments.calls, ['delete 4 5']);
      expect(inSheet(find.text('notes.pdf')), findsNothing);
      expect(find.text(en.attachmentDeleted), findsOneWidget);

      data.details.detailsByTask[4] = const TaskDetails();
      await choose(tester, photo, en.attachmentDelete);
      await tester.tap(find.text(en.attachmentDeleteConfirm));
      await tester.pumpAndSettle();
      expect(data.attachments.calls.last, 'delete 4 3 cover');
      expect(inSheet(find.text('photo.png')), findsNothing);
    });

    testWidgets('a refused change says why and changes nothing', (
      tester,
    ) async {
      await openDetail(tester, data.tasks.find(4)!);
      data.attachments.failure = const DomainError(412, code: 3008);

      await choose(tester, pdf, en.attachmentDelete);
      await tester.tap(find.text(en.attachmentDeleteConfirm));
      await tester.pumpAndSettle();

      expect(find.text(en.attachmentArchived), findsOneWidget);
      expect(inSheet(find.text('notes.pdf')), findsOneWidget);
    });
  });

  group('who may change attachments', () {
    testWidgets('in an archived project files open, share and save; nothing '
        'adds, deletes or sets the cover', (tester) async {
      data.details.detailsByTask[6] = TaskDetails(
        attachments: [sampleAttachment(id: 7, taskId: 6)],
      );
      await openDetail(tester, data.tasks.find(6)!);

      expect(inSheet(find.byTooltip(en.attachmentAdd)), findsNothing);
      expect(await menuOf(tester, sampleAttachment(id: 7, taskId: 6)), [
        en.attachmentOpen,
        en.attachmentShare,
        en.attachmentSaveToDevice,
      ]);
    });

    testWidgets('a server with attachments off offers no changes, and no '
        'section without any', (tester) async {
      data.attachments.uploadsEnabled = false;
      await openDetail(tester, data.tasks.find(4)!);

      expect(inSheet(find.byTooltip(en.attachmentAdd)), findsNothing);
      expect(await menuOf(tester, pdf), [
        en.attachmentOpen,
        en.attachmentShare,
        en.attachmentSaveToDevice,
      ]);

      await tester.tap(inSheet(find.byTooltip(en.taskDetailClose)));
      await tester.pumpAndSettle();
      data.details.detailsByTask[4] = const TaskDetails();
      final context = containerOf(tester)
          .read(appRouterProvider)
          .routerDelegate
          .navigatorKey
          .currentContext!;
      unawaited(showTaskDetail(context, task: data.tasks.find(4)!));
      await tester.pumpAndSettle();
      expect(inSheet(find.text(en.taskDetailAttachments)), findsNothing);
    });

    testWidgets('a task this device has not synced takes no files', (
      tester,
    ) async {
      data.details.detailsByTask[40] = TaskDetails(
        attachments: [sampleAttachment(id: 8, taskId: 40)],
      );
      await openDetail(tester, sampleTask(id: 40, title: 'From a link'));

      expect(inSheet(find.text('photo.png')), findsOneWidget);
      expect(inSheet(find.byTooltip(en.attachmentAdd)), findsNothing);
    });
  });
}
