import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/attachments/attachment_images.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/user_avatar.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_tasks_screen.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/reaction_chips.dart';
import 'package:vikunja_mobile/features/tasks/presentation/rich_text/attachment_image_viewer.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_meta.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row_parts.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';
import '../../helpers/task_details_fakes.dart';

const _anna = User(id: 9, username: 'anna', name: 'Anna');
const _ben = User(id: 10, username: 'ben', name: 'Ben');
const _me = User(id: 7, username: 'alice', name: 'Alice Example');

void main() {
  final now = DateTime(2026, 10, 12, 12);
  late SyncFakes data;
  late FakeExternalLinkOpener linkOpener;

  setUp(() {
    linkOpener = FakeExternalLinkOpener();
    data = SyncFakes(now: now);
    data.projects.all = [
      sampleProject(id: 1, title: 'Work', identifier: 'WORK'),
      sampleProject(id: 2, title: 'Clients', parent: 1),
      sampleProject(id: 3, title: 'Acme', parent: 2, identifier: 'ACME'),
    ];
    data.tasks.all = [
      sampleTask(
        id: 4,
        title: 'Ship the order',
        projectId: 3,
        identifier: 'OLD-4',
        created: DateTime(2026, 10, 10, 12),
        updated: DateTime(2026, 10, 12, 11),
        createdBy: _anna,
        description: '<p>Ask <strong>Anna</strong></p>',
      ),
      const Task(id: -1, title: 'Fresh task', projectId: 1),
    ];
  });

  Finder sheet() => find.byType(TaskDetailSheet).last;

  Finder inSheet(Finder matching) =>
      find.descendant(of: sheet(), matching: matching);

  Future<void> pumpApp(WidgetTester tester) async {
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
      linkOpener: linkOpener,
      overrides: [clockProvider.overrideWithValue(() => now)],
    );
  }

  Future<void> showDetail(WidgetTester tester, int taskId) async {
    final context = containerOf(tester)
        .read(appRouterProvider)
        .routerDelegate
        .navigatorKey
        .currentContext!;
    unawaited(showTaskDetail(context, task: data.tasks.find(taskId)!));
    await tester.pumpAndSettle();
  }

  Future<void> openDetail(WidgetTester tester, int taskId) async {
    await pumpApp(tester);
    await showDetail(tester, taskId);
  }

  group('the heading', () {
    testWidgets('the identifier from the project, the colour bubble, the '
        'project path and the checklist', (tester) async {
      data.tasks.all = [
        data.tasks
            .find(4)!
            .copyWith(
              hexColor: 'ff0000',
              description: [
                '<ul data-type="taskList">',
                '<li data-type="taskItem" data-checked="true"><label>',
                '<input type="checkbox" checked><span></span></label>',
                '<div><p>Pack</p></div></li>',
                '<li data-type="taskItem" data-checked="false"><label>',
                '<input type="checkbox"><span></span></label>',
                '<div><p>Send</p></div></li></ul>',
              ].join(),
            ),
      ];
      await openDetail(tester, 4);

      // The server's identifier is stale after a move; the project's is not.
      expect(inSheet(find.text('ACME-4')), findsOneWidget);
      expect(inSheet(find.text('OLD-4')), findsNothing);
      final dot = tester.widget<ColorDot>(inSheet(find.byType(ColorDot)));
      expect(dot.color, const Color(0xFFFF0000));
      for (final title in ['Work', 'Clients', 'Acme']) {
        expect(inSheet(find.text(title)), findsOneWidget);
      }
      expect(
        inSheet(find.text(en.taskChecklistProgress(1, 2))),
        findsOneWidget,
      );
    });

    testWidgets('the project path starts at the first ancestor on this '
        'device', (tester) async {
      data.projects.all = [
        sampleProject(id: 3, title: 'Acme', parent: 2, identifier: 'ACME'),
      ];
      await openDetail(tester, 4);

      expect(inSheet(find.text('Acme')), findsOneWidget);
      expect(inSheet(find.text('Clients')), findsNothing);
    });

    testWidgets('a project in the path closes the sheet and opens that '
        'project', (tester) async {
      await openDetail(tester, 4);

      await tester.tap(inSheet(find.text('Clients')));
      await tester.pumpAndSettle();

      expect(find.byType(TaskDetailSheet), findsNothing);
      expect(
        containerOf(tester).read(appRouterProvider).state.matchedLocation,
        AppRoutes.project(2),
      );
      expect(find.byType(ProjectTasksScreen), findsOneWidget);
    });

    testWidgets('a renamed or moved project shows while the sheet is open', (
      tester,
    ) async {
      await openDetail(tester, 4);

      data.projects.all = [
        ...data.projects.all.where((project) => project.id != 3),
        sampleProject(id: 3, title: 'Acme Corp', parent: 1, identifier: 'AC'),
      ];
      await tester.pumpAndSettle();

      expect(inSheet(find.text('Acme Corp')), findsOneWidget);
      expect(inSheet(find.text('Clients')), findsNothing);
      expect(inSheet(find.text('AC-4')), findsOneWidget);
    });

    testWidgets('labels once each by title, assignees with their avatars', (
      tester,
    ) async {
      data.tasks.all = [
        data.tasks
            .find(4)!
            .copyWith(
              labels: [
                sampleLabel(id: 2, title: 'zeta'),
                sampleLabel(id: 1, title: 'Alpha'),
                sampleLabel(id: 2, title: 'zeta'),
              ],
              assignees: const [_anna, _ben],
            ),
      ];
      await openDetail(tester, 4);

      final labels = tester
          .widgetList<LabelPill>(inSheet(find.byType(LabelPill)))
          .map((chip) => chip.label.title);
      expect(labels, ['Alpha', 'zeta']);
      expect(inSheet(find.byType(UserAvatar)), findsNWidgets(2));
    });
  });

  group('the metadata line', () {
    testWidgets('created by whom and updated, relative, the dates for '
        'screen readers', (tester) async {
      final semantics = tester.ensureSemantics();
      await openDetail(tester, 4);

      final created = en.taskDetailCreatedBy(en.relativeDaysAgo(2), 'Anna');
      expect(inSheet(find.text(created)), findsOneWidget);
      expect(
        inSheet(find.text(en.taskDetailUpdated(en.relativeHoursAgo(1)))),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(inSheet(find.text(created))).label,
        en.taskDetailCreatedBy('Oct 10, 2026 12:00 PM', 'Anna'),
      );
      expect(find.textContaining('Done '), findsNothing);
      semantics.dispose();
    });

    testWidgets('done says when, and an unchanged task has no update', (
      tester,
    ) async {
      data.tasks.all = [
        data.tasks
            .find(4)!
            .copyWith(
              done: true,
              doneAt: DateTime(2026, 10, 12, 11, 30).toUtc(),
              updated: DateTime(2026, 10, 10, 12).toUtc(),
              createdBy: null,
            ),
      ];
      await openDetail(tester, 4);

      expect(
        inSheet(find.text(en.taskDetailCreated(en.relativeDaysAgo(2)))),
        findsOneWidget,
      );
      expect(
        inSheet(find.text(en.taskDetailDoneWhen(en.relativeMinutesAgo(30)))),
        findsOneWidget,
      );
      expect(inSheet(find.textContaining('Updated')), findsNothing);
    });
  });

  group('online details', () {
    testWidgets('one read on opening; attachments with their previews, sizes '
        'and the cover; reactions under the title', (tester) async {
      final semantics = tester.ensureSemantics();
      data.details.detailsByTask[4] = TaskDetails(
        attachments: [
          sampleAttachment(id: 3, taskId: 4, size: 1536),
          sampleAttachment(
            id: 5,
            taskId: 4,
            name: 'notes.pdf',
            mime: 'application/pdf',
            size: 1500000,
          ),
          sampleAttachment(
            id: 6,
            taskId: 4,
            name: 'logo.svg',
            mime: 'image/svg+xml',
            size: 10,
          ),
        ],
        coverImageAttachmentId: 3,
        reactions: const {
          '👍': [_anna, _me],
          '🎉': [_ben],
        },
      );
      data.attachmentImages.fallback = samplePngImage;
      await openDetail(tester, 4);

      expect(data.details.calls, ['details 4']);
      expect(inSheet(find.text(en.taskDetailAttachments)), findsOneWidget);
      expect(inSheet(find.text('photo.png')), findsOneWidget);
      expect(inSheet(find.text('1.5 KB')), findsOneWidget);
      expect(inSheet(find.text('notes.pdf')), findsOneWidget);
      expect(inSheet(find.text('1.43 MB')), findsOneWidget);
      expect(inSheet(find.text(en.taskDetailCoverImage)), findsOneWidget);
      expect(
        inSheet(find.byIcon(Icons.picture_as_pdf_outlined)),
        findsOneWidget,
      );
      // Only an image the server can preview is asked for, at the list's size.
      expect(data.attachmentImages.loads, ['4 3 md']);

      expect(inSheet(find.text('👍 2')), findsOneWidget);
      expect(inSheet(find.text('🎉 1')), findsOneWidget);
      expect(
        tester.getSemantics(inSheet(find.text('👍 2'))),
        matchesSemantics(
          label: en.reactionBySeveral('Anna', 'Alice Example', '👍'),
          hasSelectedState: true,
          isSelected: true,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          onTapHint: en.reactionRemoveMine,
        ),
      );
      expect(
        tester.getSemantics(inSheet(find.text('🎉 1'))),
        matchesSemantics(
          label: en.reactionByOne('Ben', '🎉'),
          hasSelectedState: true,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          onTapHint: en.reactionAddMine,
        ),
      );
      final colors = Theme.of(tester.element(sheet())).colorScheme;
      // Highlighted where the signed-in user reacted.
      expect(
        tester.widget<Text>(inSheet(find.text('👍 2'))).style?.color,
        colors.onPrimaryContainer,
      );
      expect(
        tester.widget<Text>(inSheet(find.text('🎉 1'))).style?.color,
        colors.onSurface,
      );

      await tester.tap(inSheet(find.text('photo.png')));
      await tester.pumpAndSettle();
      expect(find.byType(AttachmentImageViewer), findsOneWidget);
      expect(data.attachmentImages.loads, contains('4 3 original'));
      semantics.dispose();
    });

    testWidgets('sizes use the decimal separator of the language', (
      tester,
    ) async {
      useLocale(tester, const Locale('de'));
      data.details.detailsByTask[4] = TaskDetails(
        attachments: [
          sampleAttachment(
            id: 3,
            taskId: 4,
            name: 'notes.txt',
            mime: 'text/plain',
            size: 3456789,
          ),
        ],
      );
      await openDetail(tester, 4);

      expect(inSheet(find.text('3,3 MB')), findsOneWidget);
    });

    testWidgets('an unread task is marked read, a read one is not', (
      tester,
    ) async {
      data.details.detailsByTask[4] = const TaskDetails(isUnread: true);
      await openDetail(tester, 4);

      expect(data.details.markedRead, [4]);

      await tester.tap(inSheet(find.byTooltip(en.taskDetailClose)));
      await tester.pumpAndSettle();
      data.details.detailsByTask[4] = const TaskDetails();
      await showDetail(tester, 4);

      expect(data.details.calls, ['details 4', 'markRead 4', 'details 4']);
    });

    testWidgets('a failed mark read goes unnoticed', (tester) async {
      data.details
        ..detailsByTask[4] = const TaskDetails(isUnread: true)
        ..markReadFailure = const ServerFailure(500);
      await openDetail(tester, 4);

      expect(data.details.calls, ['details 4', 'markRead 4']);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('offline one quiet line with Retry; the rest of the sheet is '
        'complete', (tester) async {
      data.details.detailsFailure = const NetworkFailure(
        NetworkProblem.unreachable,
      );
      await openDetail(tester, 4);

      expect(inSheet(find.text(en.taskDetailDetailsOffline)), findsOneWidget);
      expect(inSheet(find.text('Ask Anna')), findsOneWidget);
      // Files can still be added; the server's list needs the connection.
      expect(inSheet(find.text(en.taskDetailAttachments)), findsOneWidget);
      expect(inSheet(find.text('photo.png')), findsNothing);

      data.details
        ..detailsFailure = null
        ..detailsByTask[4] = TaskDetails(
          attachments: [sampleAttachment(id: 3, taskId: 4)],
        );
      await tester.tap(inSheet(find.text(en.retry)));
      await tester.pumpAndSettle();

      expect(data.details.calls, ['details 4', 'details 4']);
      expect(inSheet(find.text(en.taskDetailDetailsOffline)), findsNothing);
      expect(inSheet(find.text('photo.png')), findsOneWidget);
    });

    testWidgets('Retry also asks again for images that needed a connection', (
      tester,
    ) async {
      const image = (4, 3, AttachmentPreviewSize.extraLarge);
      const attachmentUrl =
          'https://tasks.example.org/vikunja/api/v2/tasks/4/attachments/3';
      data.tasks.all = [
        data.tasks
            .find(4)!
            .copyWith(
              description:
                  '<p>Fence</p><img src="#" data-src="$attachmentUrl">',
            ),
      ];
      const offline = NetworkFailure(NetworkProblem.unreachable);
      data.details.detailsFailure = offline;
      data.attachmentImages.failures[image] = offline;
      await openDetail(tester, 4);
      expect(inSheet(find.text(en.richTextImageOffline)), findsOneWidget);

      data.details.detailsFailure = null;
      data.attachmentImages
        ..failures.remove(image)
        ..images[image] = samplePngImage;
      await tester.tap(inSheet(find.text(en.retry)));
      await tester.pumpAndSettle();

      expect(data.attachmentImages.loads, ['4 3 xl', '4 3 xl']);
      expect(inSheet(find.text(en.richTextImageOffline)), findsNothing);
      expect(inSheet(find.byType(Image)), findsOneWidget);
    });

    testWidgets('another failure says it could not load', (tester) async {
      data.details.detailsFailure = const ServerFailure(500);
      await openDetail(tester, 4);

      expect(inSheet(find.text(en.taskDetailDetailsFailed)), findsOneWidget);
    });

    testWidgets('a task not yet sent asks nothing and shows no line', (
      tester,
    ) async {
      await openDetail(tester, -1);

      expect(data.details.calls, isEmpty);
      expect(inSheet(find.text(en.taskDetailDetailsOffline)), findsNothing);
      expect(inSheet(find.text(en.taskDetailDetailsFailed)), findsNothing);
    });
  });

  group('comments', () {
    void seedComments(int count, {int perPage = 50}) {
      data.details
        ..detailsByTask[4] = TaskDetails(commentCount: count)
        ..commentsPerPage = perPage
        ..commentsByTask[4] = [
          for (var id = 1; id <= count; id++)
            sampleComment(id: id, html: '<p>Comment $id</p>'),
        ];
    }

    testWidgets('only on request, oldest first', (tester) async {
      seedComments(2);
      await openDetail(tester, 4);

      expect(inSheet(find.text(en.taskDetailComments(2))), findsOneWidget);
      expect(data.details.calls, ['details 4']);

      await tester.tap(inSheet(find.text(en.taskDetailShowComments)));
      await tester.pumpAndSettle();

      expect(data.details.calls.last, 'comments 4 page 1 oldest');
      expect(inSheet(find.text(en.taskDetailShowComments)), findsNothing);
      expect(
        tester.getTopLeft(inSheet(find.text('Comment 1'))).dy,
        lessThan(tester.getTopLeft(inSheet(find.text('Comment 2'))).dy),
      );
      expect(inSheet(find.text('Anna')), findsNWidgets(2));
      expect(inSheet(find.text(en.commentsOldestFirst)), findsOneWidget);
    });

    testWidgets('"Show comments" stays in place, disabled, while the page '
        'loads, and screen readers hear the result', (tester) async {
      seedComments(2);
      final page = Completer<void>();
      data.details.beforeCall = (call) async {
        if (call.startsWith('comments')) await page.future;
      };
      await openDetail(tester, 4);

      await tester.tap(inSheet(find.text(en.taskDetailShowComments)));
      await tester.pump();

      final button = find.ancestor(
        of: inSheet(find.text(en.taskDetailShowComments)),
        matching: find.byWidgetPredicate((widget) => widget is OutlinedButton),
      );
      expect(button, findsOneWidget);
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      expect(tester.takeAnnouncements(), isEmpty);

      page.complete();
      await tester.pumpAndSettle();

      expect(inSheet(find.text(en.taskDetailShowComments)), findsNothing);
      expect(inSheet(find.text('Comment 1')), findsOneWidget);
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.commentsLoaded(2)),
      ]);
    });

    testWidgets('a failed page is announced too', (tester) async {
      seedComments(2);
      data.details.commentsFailure = const NetworkFailure(
        NetworkProblem.unreachable,
      );
      await openDetail(tester, 4);

      await tester.tap(inSheet(find.text(en.taskDetailShowComments)));
      await tester.pumpAndSettle();

      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.commentsNeedConnection),
      ]);
    });

    testWidgets('no comments: the section says so and reads nothing', (
      tester,
    ) async {
      data.details.detailsByTask[4] = const TaskDetails();
      await openDetail(tester, 4);

      expect(inSheet(find.text(en.commentsHeading)), findsOneWidget);
      expect(inSheet(find.text(en.commentsEmpty)), findsOneWidget);
      expect(inSheet(find.text(en.taskDetailShowComments)), findsNothing);
      expect(data.details.calls, ['details 4']);
    });

    testWidgets('pages load on "Load more"', (tester) async {
      seedComments(3, perPage: 2);
      await openDetail(tester, 4);
      await tester.tap(inSheet(find.text(en.taskDetailShowComments)));
      await tester.pumpAndSettle();

      expect(inSheet(find.text('Comment 3')), findsNothing);
      await tester.tap(inSheet(find.text(en.taskDetailMoreComments)));
      await tester.pumpAndSettle();

      expect(data.details.calls.last, 'comments 4 page 2 oldest');
      expect(inSheet(find.text('Comment 3')), findsOneWidget);
      expect(inSheet(find.text(en.taskDetailMoreComments)), findsNothing);
    });

    testWidgets('the order follows the settings and turns for this sheet', (
      tester,
    ) async {
      seedComments(2);
      data.shared.settings = const UserSettings(
        commentSortOrder: CommentSortOrder.newestFirst,
      );
      await openDetail(tester, 4);
      await tester.tap(inSheet(find.text(en.taskDetailShowComments)));
      await tester.pumpAndSettle();

      expect(data.details.calls.last, 'comments 4 page 1 newest');
      expect(
        tester.getTopLeft(inSheet(find.text('Comment 2'))).dy,
        lessThan(tester.getTopLeft(inSheet(find.text('Comment 1'))).dy),
      );

      await tester.tap(inSheet(find.text(en.commentsNewestFirst)));
      await tester.pumpAndSettle();

      expect(data.details.calls.last, 'comments 4 page 1 oldest');
      expect(inSheet(find.text(en.commentsOldestFirst)), findsOneWidget);
      expect(
        tester.getTopLeft(inSheet(find.text('Comment 1'))).dy,
        lessThan(tester.getTopLeft(inSheet(find.text('Comment 2'))).dy),
      );
    });

    testWidgets('edited comments, reactions and the reply header', (
      tester,
    ) async {
      data.details
        ..detailsByTask[4] = const TaskDetails(commentCount: 3)
        ..commentsByTask[4] = [
          sampleComment(id: 1, html: '<p>First</p>'),
          sampleComment(
            id: 2,
            author: _ben,
            html: [
              '<blockquote data-comment-id="1"><p>First</p></blockquote>',
              '<p>Agreed</p>',
            ].join(),
            updated: DateTime.utc(2026, 10, 12, 10),
            reactions: const {
              '👀': [_anna],
            },
          ),
          sampleComment(
            id: 3,
            html: [
              '<blockquote data-comment-id="99"><p>Gone</p></blockquote>',
              '<p>Later</p>',
            ].join(),
          ),
        ];
      await openDetail(tester, 4);
      await tester.tap(inSheet(find.text(en.taskDetailShowComments)));
      await tester.pumpAndSettle();

      expect(
        inSheet(find.textContaining(en.commentEdited(''))),
        findsOneWidget,
      );
      expect(inSheet(find.text(en.richTextReplyTo('Anna'))), findsOneWidget);
      expect(inSheet(find.text('Gone')), findsOneWidget);
      expect(inSheet(find.text('👀 1')), findsOneWidget);
      expect(
        tester.getSemantics(inSheet(find.text('👀 1'))).label,
        en.reactionByOne('Anna', '👀'),
      );
    });

    testWidgets('a failed page says so and retries', (tester) async {
      seedComments(1);
      data.details.commentsFailure = const NetworkFailure(
        NetworkProblem.unreachable,
      );
      await openDetail(tester, 4);
      await tester.tap(inSheet(find.text(en.taskDetailShowComments)));
      await tester.pumpAndSettle();

      expect(inSheet(find.text(en.commentsNeedConnection)), findsOneWidget);

      data.details.commentsFailure = null;
      await tester.tap(inSheet(find.text(en.retry)));
      await tester.pumpAndSettle();

      expect(inSheet(find.text('Comment 1')), findsOneWidget);
      expect(inSheet(find.text(en.commentsNeedConnection)), findsNothing);
    });
  });

  group('links in the description', () {
    Future<void> openWithLinks(WidgetTester tester, String html) async {
      data.tasks.all = [
        ...data.tasks.all.where((task) => task.id != 4),
        data.tasks.find(4)!.copyWith(description: html),
      ];
      await openDetail(tester, 4);
    }

    testWidgets('a web page and a mail address go to the system', (
      tester,
    ) async {
      await openWithLinks(
        tester,
        [
          '<p><a href="https://example.com/docs">docs</a> ',
          '<a href="mailto:anna@example.com">mail</a> ',
          '<a href="/projects/3">relative</a></p>',
        ].join(),
      );

      await tester.tapOnText(find.textRange.ofSubstring('docs'));
      await tester.tapOnText(find.textRange.ofSubstring('mail'));
      await tester.tapOnText(find.textRange.ofSubstring('relative'));
      await tester.pumpAndSettle();

      expect(linkOpener.opened, [
        Uri.parse('https://example.com/docs'),
        Uri.parse('mailto:anna@example.com'),
        Uri.parse('https://tasks.example.org/projects/3'),
      ]);
    });

    testWidgets('a link nothing can open says so', (tester) async {
      linkOpener = FakeExternalLinkOpener(succeeds: false);
      await openWithLinks(tester, '<p><a href="tel:+4930123">call</a></p>');

      await tester.tapOnText(find.textRange.ofSubstring('call'));
      await tester.pumpAndSettle();

      expect(inSheet(find.text(en.linkCannotOpen)), findsOneWidget);
    });

    testWidgets('a task URL of the account opens over this sheet', (
      tester,
    ) async {
      data.tasks.all = [
        ...data.tasks.all,
        sampleTask(id: 8, title: 'Invoice', projectId: 3),
      ];
      await openWithLinks(
        tester,
        [
          '<p>See <a href="https://tasks.example.org/vikunja/tasks/8">',
          'the invoice</a> and ',
          '<a href="https://tasks.example.org/vikunja/tasks/8">',
          'https://tasks.example.org/vikunja/tasks/8</a></p>',
        ].join(),
      );

      await tester.tapOnText(find.textRange.ofSubstring('the invoice'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailSheet), findsNWidgets(2));
      expect(inSheet(find.text('Invoice')), findsWidgets);

      await tester.tap(inSheet(find.byTooltip(en.taskDetailClose)));
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.text('ACME-8 Invoice')));
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailSheet), findsNWidgets(2));
      expect(linkOpener.opened, isEmpty);
    });

    testWidgets('while a linked task is read online the sheet shows '
        'progress and further taps wait', (tester) async {
      data.resolver.online[const TaskById(50)] = sampleTask(
        id: 50,
        title: 'Remote task',
        projectId: 3,
      );
      final read = Completer<void>();
      data.resolver.beforeResolve = (_) => read.future;
      const href = 'https://tasks.example.org/vikunja/tasks/50';
      await openWithLinks(tester, '<p><a href="$href">$href</a></p>');

      await tester.tap(inSheet(find.text(href)));
      await tester.pump();
      expect(inSheet(find.byType(LinearProgressIndicator)), findsOneWidget);
      await tester.tap(inSheet(find.text(href)));
      await tester.pump();

      read.complete();
      await tester.pumpAndSettle();

      expect(data.resolver.resolved, [const TaskById(50)]);
      expect(find.byType(TaskDetailSheet), findsNWidgets(2));
      expect(
        find.descendant(
          of: find.byType(TaskDetailSheet).first,
          matching: find.byType(LinearProgressIndicator),
        ),
        findsNothing,
      );
    });

    testWidgets('a linked task not on this device is read online, and one '
        'that is gone says so', (tester) async {
      data.resolver.online[const TaskById(50)] = sampleTask(
        id: 50,
        title: 'Remote task',
        projectId: 3,
      );
      await openWithLinks(
        tester,
        [
          '<p><a href="https://tasks.example.org/vikunja/tasks/50">',
          'https://tasks.example.org/vikunja/tasks/50</a> ',
          '<a href="https://tasks.example.org/vikunja/tasks/51">',
          'https://tasks.example.org/vikunja/tasks/51</a></p>',
        ].join(),
      );

      await tester.tap(
        inSheet(find.text('https://tasks.example.org/vikunja/tasks/51')),
      );
      await tester.pumpAndSettle();
      expect(inSheet(find.text(en.taskOpenNotFound)), findsOneWidget);
      expect(find.byType(TaskDetailSheet), findsOneWidget);

      await tester.tap(
        inSheet(find.text('https://tasks.example.org/vikunja/tasks/50')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailSheet), findsNWidgets(2));
      expect(inSheet(find.text('Remote task')), findsWidgets);
    });
  });

  testWidgets('the reaction label: one, up to ten names, then ten and how '
      'many more', (tester) async {
    List<User> users(int count) => [
      for (var i = 1; i <= count; i++) User(id: i, username: 'u$i'),
    ];
    expect(reactionLabel(en, '👍', users(1)), en.reactionByOne('u1', '👍'));
    expect(
      reactionLabel(en, '👍', users(3)),
      en.reactionBySeveral('u1, u2', 'u3', '👍'),
    );
    expect(
      reactionLabel(en, '👍', users(10)),
      en.reactionBySeveral(
        [for (var i = 1; i <= 9; i++) 'u$i'].join(', '),
        'u10',
        '👍',
      ),
    );
    expect(
      reactionLabel(en, '👍', users(11)),
      en.reactionByMany(
        [for (var i = 1; i <= 10; i++) 'u$i'].join(', '),
        1,
        '👍',
      ),
    );
    expect(
      reactionLabel(en, '👍', users(12)),
      en.reactionByMany(
        [for (var i = 1; i <= 10; i++) 'u$i'].join(', '),
        2,
        '👍',
      ),
    );
    expect(
      reactionLabel(de, '👍', users(2)),
      'u1 und u2 haben mit 👍 reagiert',
    );
  });
}
