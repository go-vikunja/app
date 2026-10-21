import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/widgets/adaptive_navigation_bar.dart';
import 'package:vikunja_mobile/core/attachments/pending_upload.dart';
import 'package:vikunja_mobile/core/auth/web_authenticator.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/share/share_intent_source.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/api_token_form_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/api_tokens_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/avatar_crop_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/avatar_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/caldav_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/data_export_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/one_time_secret_view.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/sessions_page.dart';
import 'package:vikunja_mobile/features/attachments/application/attachment_picker.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_card.dart';
import 'package:vikunja_mobile/features/common/presentation/search_pill.dart';
import 'package:vikunja_mobile/features/description_editor/application/editor_protocol.dart';
import 'package:vikunja_mobile/features/description_editor/presentation/description_editor_page.dart';
import 'package:vikunja_mobile/features/description_editor/presentation/editor_toolbar.dart';
import 'package:vikunja_mobile/features/description_editor/presentation/mention_bar.dart';
import 'package:vikunja_mobile/features/filters/presentation/filter_field.dart';
import 'package:vikunja_mobile/features/home/presentation/description_conflict_sheet.dart';
import 'package:vikunja_mobile/features/home/presentation/reauth_banner.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connection_error_card.dart';
import 'package:vikunja_mobile/features/projects/presentation/board/board_column.dart';
import 'package:vikunja_mobile/features/projects/presentation/board/new_column_tile.dart';
import 'package:vikunja_mobile/features/projects/presentation/board/project_board.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/duplicate_project_sheet.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/new_project_sheet.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/project_edit_page.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/project_views_page.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/view_form_sheet.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_row.dart';
import 'package:vikunja_mobile/features/projects/presentation/reorder_slot.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_plan.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_service_provider.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/magic_suggestions.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/quick_add_help_sheet.dart';
import 'package:vikunja_mobile/features/share/presentation/share_sheet.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/saved_filter_form_page.dart';
import 'package:vikunja_mobile/features/sync/presentation/first_sync_screen.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/new_task_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comment_composer.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/task_edit_page.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/assignee_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relations/add_relation_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';
import 'package:vikunja_mobile/features/upcoming/presentation/day_strip.dart';
import 'package:vikunja_mobile/features/upcoming/presentation/upcoming_screen.dart';

import '../features/account_settings/avatar_fakes.dart';
import '../features/accounts/accounts_harness.dart';
import '../features/tasks/edit_page_harness.dart';
import '../helpers/account_security_fakes.dart';
import '../helpers/account_settings_fakes.dart';
import '../helpers/attachment_picker_fake.dart';
import '../helpers/auth_fakes.dart';
import '../helpers/editor_bridge_fakes.dart';
import '../helpers/fake_quick_add_service.dart';
import '../helpers/fakes.dart';
import '../helpers/label_user_fakes.dart';
import '../helpers/pump_app.dart';
import '../helpers/sample_data.dart';
import '../helpers/server_connections.dart';
import '../helpers/sync_fakes.dart';
import '../helpers/task_details_fakes.dart';

// Layout overflows are reported as test failures, so reaching the end of each
// scenario without an exception is the assertion.
void main() {
  const smallPhone = Size(320, 640);
  const locales = [Locale('en'), Locale('de')];

  void useWorstCase(WidgetTester tester, Locale locale) {
    usePhoneSurface(tester, logicalSize: smallPhone);
    useAccessibilityExtremes(tester);
    useLocale(tester, locale);
  }

  Future<void> scrollToEnd(WidgetTester tester, Finder scrollView) async {
    final position = tester
        .state<ScrollableState>(
          find
              .descendant(of: scrollView, matching: find.byType(Scrollable))
              .first,
        )
        .position;
    for (var i = 0; i < 80 && position.extentAfter > 0; i++) {
      await tester.drag(scrollView, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    expect(position.extentAfter, 0);
  }

  /// Scrolls the row into view below the Overview's header and taps its
  /// title at its start, clear of the floating action button that may
  /// cover the row's end on a small screen.
  Future<void> tapRow(WidgetTester tester, String titleStart) async {
    final title = find.textContaining(titleStart);
    await tester.scrollUntilVisible(
      title,
      300,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getTopLeft(title) + const Offset(4, 4));
    await tester.pumpAndSettle();
  }

  SyncFakes richData({SyncStatus? status}) {
    final now = DateTime.now();
    final label = sampleLabel(
      id: 1,
      title: 'A rather long label title',
      hexColor: 'ffeb10',
    );
    final data = SyncFakes(now: now, status: status);
    data.projects.all = [
      sampleProject(
        id: 1,
        title: 'Work with a very long project title',
        favorite: true,
        hexColor: '1973ff',
      ),
      sampleProject(
        id: 2,
        title: 'Child project with another long title',
        parent: 1,
      ),
    ];
    data.tasks.all = [
      for (var i = 1; i <= 6; i++)
        sampleTask(
          id: i,
          title: 'Task $i with a title long enough to wrap onto several lines',
          due: i == 6 ? null : now.add(Duration(days: i * 3 - 5)),
          identifier: 'LONGIDENT-$i',
          priority: TaskPriority.doNow,
          labels: [label, label],
          favorite: true,
          assignees: const [
            User(
              id: 1,
              username: 'maximiliane',
              name: 'Maximiliane Musterfrau-Beispielhausen',
            ),
          ],
          reminders: const [
            TaskReminder(
              relativePeriod: Duration(hours: -1),
              relativeTo: ReminderRelativeTo.dueDate,
            ),
          ],
          repeatAfter: const Duration(days: 14),
          percentDone: 0.5,
          description:
              '<p>Some description text that is long enough to wrap.</p>',
        ),
    ];
    return data;
  }

  /// A project whose kanban view opens: four columns, a long title, a full
  /// one, the done one and an empty one.
  SyncFakes kanbanData({bool archived = false}) {
    final now = DateTime.now();
    final data = richData();
    final kanban = sampleKanbanView(
      id: 14,
      projectId: 1,
      title: 'A kanban view with a long title',
      defaultBucketId: 21,
      doneBucketId: 23,
    );
    data.projects.all = [
      sampleProject(
        id: 1,
        title: 'Work with a very long project title',
        archived: archived,
        views: [sampleListView(id: 11, projectId: 1), kanban],
      ),
    ];
    data.tasks.all = [
      ...data.tasks.all,
      sampleTask(id: 7, title: 'Finished', done: true, doneAt: now),
    ];
    data.tasks.setBoard(
      kanban,
      buckets: const [
        Bucket(
          id: 21,
          viewId: 14,
          title: 'A column whose title is long enough to wrap twice',
          count: 30,
          position: 1,
        ),
        Bucket(
          id: 22,
          viewId: 14,
          title: 'Doing',
          count: 2,
          limit: 2,
          position: 2,
        ),
        Bucket(id: 23, viewId: 14, title: 'Done', count: 1, position: 3),
        Bucket(id: 24, viewId: 14, title: 'Empty', position: 4),
      ],
      snapshot: const {
        1: (bucketId: 21, position: 1),
        2: (bucketId: 21, position: 2),
        3: (bucketId: 21, position: 3),
        4: (bucketId: 21, position: 4),
        5: (bucketId: 22, position: 5),
        6: (bucketId: 22, position: 6),
        7: (bucketId: 23, position: 7),
      },
      loadedAt: now,
    );
    data.listPreferences.lastViews[1] = 14;
    return data;
  }

  for (final locale in locales) {
    testWidgets('overview with tasks at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      await pumpSignedInApp(tester, sync: richData());

      await scrollToEnd(tester, find.byType(CustomScrollView));
      expect(tester.takeException(), isNull);
    });

    testWidgets('task detail sheet at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      await pumpSignedInApp(tester, sync: richData());

      await tapRow(tester, 'Task 1 ');

      expect(find.byType(TaskDetailSheet), findsOneWidget);
      await scrollToEnd(tester, find.byType(TaskDetailSheet));
      expect(tester.takeException(), isNull);
    });

    testWidgets('task detail sheet with a rich description, attachments and '
        'comments at 200 % in dark mode (${locale.languageCode})', (
      tester,
    ) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      final data = richData();
      const root = 'https://tasks.example.org/vikunja';
      const maxi = User(
        id: 1,
        username: 'maximiliane',
        name: 'Maximiliane Musterfrau-Beispielhausen',
      );
      data.tasks.all = [
        data.tasks.all.first.copyWith(
          description: [
            '<h1>A heading that is long enough to wrap</h1>',
            '<p>Text with <strong>bold</strong>, <em>italic</em>, ',
            '<code>code</code>, <a href="https://example.com">a link</a>, ',
            '<mention-user data-id="maximiliane" ',
            'data-label="Maximiliane Musterfrau-Beispielhausen">',
            '</mention-user> and <a href="$root/tasks/2">$root/tasks/2</a>',
            ' and <a href="$root/tasks/99">$root/tasks/99</a></p>',
            '<ul data-type="taskList"><li data-type="taskItem" ',
            'data-checked="true"><label><input type="checkbox" checked>',
            '<span></span></label><div><p>A checked item with a long ',
            'text</p></div></li></ul>',
            '<ol start="3"><li><p>Third</p></li></ol>',
            '<blockquote><p>A quote</p></blockquote>',
            '<pre><code>final longLine = "does not wrap but scrolls";',
            '</code></pre>',
            '<table><tr><th>Header cell</th><th>Another header</th></tr>',
            '<tr><td colspan="2">A cell across both columns</td></tr>',
            '</table>',
            '<img src="$root/api/v2/tasks/1/attachments/3" alt="Photo">',
            '<img src="https://cdn.example.com/very-long-image-name.png">',
          ].join(),
        ),
        ...data.tasks.all.skip(1),
      ];
      data.details
        ..detailsByTask[1] = TaskDetails(
          attachments: [
            sampleAttachment(
              id: 3,
              name: 'a-photo-with-a-rather-long-file-name.png',
              size: 3456789,
            ),
            sampleAttachment(
              id: 4,
              name: 'quarterly-report-final-version.pdf',
              mime: 'application/pdf',
            ),
          ],
          coverImageAttachmentId: 3,
          reactions: const {
            '👍': [maxi],
            '🎉': [maxi],
          },
          commentCount: 2,
        )
        ..commentsByTask[1] = [
          sampleComment(
            id: 1,
            author: maxi,
            html: '<p>A first comment long enough to wrap onto lines</p>',
            reactions: const {
              '👀': [maxi],
            },
          ),
          sampleComment(
            id: 2,
            html: [
              '<blockquote data-comment-id="1"><p>A first comment</p>',
              '</blockquote><p>A reply</p>',
            ].join(),
            updated: DateTime.now().toUtc(),
          ),
        ];
      data.attachmentImages.fallback = samplePngImage;
      await pumpSignedInApp(tester, sync: data);

      await tapRow(tester, 'Task 1 ');
      expect(find.byType(TaskDetailSheet), findsOneWidget);
      await scrollToEnd(tester, find.byType(TaskDetailSheet));
      expect(tester.takeException(), isNull);

      await tester.tap(find.text(l10n.taskDetailShowComments));
      await tester.pumpAndSettle();
      await scrollToEnd(tester, find.byType(TaskDetailSheet));
      expect(find.text(l10n.richTextReplyTo(maxi.name)), findsOneWidget);
      expect(tester.takeException(), isNull);

      final photo = find.text('a-photo-with-a-rather-long-file-name.png');
      await tester.scrollUntilVisible(
        photo,
        -200,
        scrollable: find
            .descendant(
              of: find.byType(TaskDetailSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      for (var i = 0; i < 20; i++) {
        final y = tester.getCenter(photo).dy;
        if (y > 120 && y < 560) break;
        await tester.drag(
          find.byType(TaskDetailSheet),
          Offset(0, y < 120 ? 150 : -150),
        );
        await tester.pumpAndSettle();
      }
      await tester.tap(photo);
      await tester.pumpAndSettle();
      expect(find.byTooltip(l10n.imageViewerClose), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the comment field with a reply and suggestions, a '
        "comment's menu, reactions and the add-reaction sheet at 200 % in "
        'dark mode (${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      final data = richData();
      const maxi = User(
        id: 1,
        username: 'maximiliane',
        name: 'Maximiliane Musterfrau-Beispielhausen',
      );
      const me = User(id: 7, username: 'alice', name: 'Alice Example');
      data.tasks.all = [
        data.tasks.all.first.copyWith(commentCount: 2, isUnread: true),
        ...data.tasks.all.skip(1),
      ];
      data.details
        ..me = me
        ..detailsByTask[1] = const TaskDetails(
          commentCount: 2,
          maxPermission: Permission.write,
          reactions: {
            '👍': [maxi, me],
            'a-long-text-reaction': [maxi],
          },
        )
        ..commentsByTask[1] = [
          sampleComment(
            id: 1,
            author: maxi,
            html: '<p>A first comment long enough to wrap onto lines</p>',
            reactions: const {
              '👀': [maxi],
            },
          ),
          sampleComment(
            id: 2,
            author: me,
            html: '<p>An own comment that can be edited and deleted</p>',
          ),
        ];
      await pumpSignedInApp(
        tester,
        sync: data,
        overrides: [
          userRepositoryProvider.overrideWithValue(
            FakeUserRepository(
              projectUsers: {
                1: [maxi],
              },
            ),
          ),
        ],
      );

      await tapRow(tester, 'Task 1 ');
      expect(find.byType(CommentComposer), findsOneWidget);
      expect(tester.takeException(), isNull);

      final sheetList = find
          .descendant(
            of: find.byType(TaskDetailSheet),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text(l10n.taskDetailShowComments),
        200,
        scrollable: sheetList,
      );
      await tester.drag(sheetList, const Offset(0, -100));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.taskDetailShowComments));
      await tester.pumpAndSettle();
      await scrollToEnd(tester, find.byType(TaskDetailSheet));
      expect(tester.takeException(), isNull);

      final ownMenu = find.byTooltip(l10n.commentOptions(me.name));
      await tester.ensureVisible(ownMenu);
      await tester.pumpAndSettle();
      await tester.tap(ownMenu);
      await tester.pumpAndSettle();
      expect(find.text(l10n.commentDelete), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(l10n.commentReply));
      await tester.pumpAndSettle();
      expect(find.text(l10n.commentReplyingTo(me.name)), findsOneWidget);

      final field = find.descendant(
        of: find.byType(CommentComposer),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, 'Danke @Maxi');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.byType(MentionBar), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.descendant(
          of: find.byType(MentionBar),
          matching: find.text(maxi.name),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final addReaction = find.byTooltip(l10n.reactionAdd).first;
      await tester.ensureVisible(addReaction);
      await tester.pumpAndSettle();
      await tester.tap(addReaction);
      await tester.pumpAndSettle();
      expect(find.text(l10n.reactionOther), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('attachments with queued uploads, the add and row menus and '
        'the delete question at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      final data = richData();
      const report = 'quarterly-report-final-version-with-a-long-name.pdf';
      data.details.detailsByTask[1] = TaskDetails(
        attachments: [
          sampleAttachment(
            id: 3,
            name: 'a-photo-with-a-rather-long-file-name.png',
            size: 3456789,
          ),
          sampleAttachment(id: 4, name: report, mime: 'application/pdf'),
        ],
        coverImageAttachmentId: 3,
      );
      data.attachmentImages.fallback = samplePngImage;
      await pumpSignedInApp(tester, sync: data);
      final waiting = await data.tasks.queueUpload(
        1,
        sourcePath: '/cache/a',
        fileName: 'a-scan-waiting-for-a-connection-with-a-long-name.pdf',
      );
      final sending = await data.tasks.queueUpload(
        1,
        sourcePath: '/cache/b',
        fileName: 'holiday-video-being-uploaded-right-now.mp4',
      );
      final failed = await data.tasks.queueUpload(
        1,
        sourcePath: '/cache/c',
        fileName: 'refused.zip',
      );
      data.tasks.setUploadState(
        failed!,
        PendingUploadState.failed,
        failure: const FileTooLarge(code: 4012),
      );
      expect(waiting, isNotNull);

      await tapRow(tester, 'Task 1 ');
      final scrollable = find
          .descendant(
            of: find.byType(TaskDetailSheet),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byTooltip(l10n.attachmentAdd),
        200,
        scrollable: scrollable,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip(l10n.attachmentAdd));
      await tester.pumpAndSettle();
      expect(find.text(l10n.attachmentSourceCamera), findsOneWidget);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      final options = find.byTooltip(l10n.attachmentOptions(report));
      await tester.scrollUntilVisible(options, 200, scrollable: scrollable);
      await tester.pump();
      await tester.tap(options);
      await tester.pumpAndSettle();
      expect(find.text(l10n.attachmentSaveToDevice), findsOneWidget);
      await tester.tap(find.text(l10n.attachmentDelete));
      await tester.pumpAndSettle();
      expect(find.text(l10n.attachmentDeleteBody(report)), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();

      await scrollToEnd(tester, find.byType(TaskDetailSheet));
      expect(tester.takeException(), isNull);

      // Its progress never settles.
      data.tasks.setUploadState(sending!, PendingUploadState.sending);
      await tester.scrollUntilVisible(
        find.text('holiday-video-being-uploaded-right-now.mp4'),
        -200,
        scrollable: scrollable,
      );
      await pumpFrames(tester, 3);
      expect(find.textContaining(l10n.attachmentUploading), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('share sheet in both modes with files in every state and the '
        'account question at 200 % in dark mode (${locale.languageCode})', (
      tester,
    ) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      final accounts = ThreeAccounts();
      await accounts.seed(aliceName: 'Alice Example With A Long Name');
      final rich = richData();
      accounts.aliceData.projects.all = rich.projects.all;
      accounts.aliceData.tasks.all = rich.tasks.all;
      final source = accounts.data.shareSource;
      final held = Completer<void>();
      source
        ..copyFailures['content://f/unreadable'] = const SharedFileUnreadable()
        ..beforeCall = (call) =>
            call.contains('content://f/held') ? held.future : Future.value();
      await accounts.pump(tester);

      source.push(
        const IncomingShare(
          subject: 'A shared page with a title long enough to wrap',
          text: 'https://example.org/a/rather/long/address/to/a/page',
          files: [
            SharedFile(
              uri: 'content://f/ready',
              displayName: 'a-document-with-a-long-file-name.pdf',
              size: 123456,
            ),
            SharedFile(
              uri: 'content://f/large',
              displayName: 'a-very-large-video.mp4',
              size: 300 * 1024 * 1024,
            ),
            SharedFile(uri: 'content://f/unreadable', displayName: 'gone.txt'),
            SharedFile(uri: 'content://f/held', displayName: 'later.jpg'),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.sharePickAccountTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
      final alice = find.text('Alice Example With A Long Name');
      await tester.ensureVisible(alice);
      await tester.pumpAndSettle();
      await tester.tap(alice);
      await pumpFrames(tester, 5);

      expect(find.byType(ShareSheet), findsOneWidget);
      // Dragging would move the carets of its text fields instead.
      Future<void> stepThrough({required bool settle}) async {
        final position =
            tester
                .state<ScrollableState>(
                  find
                      .descendant(
                        of: find.byType(ShareSheet),
                        matching: find.byType(Scrollable),
                      )
                      .first,
                )
                .position
              ..jumpTo(0);
        while (true) {
          await (settle ? tester.pumpAndSettle() : pumpFrames(tester, 2));
          expect(tester.takeException(), isNull);
          if (position.extentAfter == 0) break;
          position.jumpTo(position.pixels + 200);
        }
      }

      // The copy's progress never settles while it is held.
      await stepThrough(settle: false);
      expect(find.text(l10n.shareFilePreparing), findsOneWidget);
      held.complete();
      await tester.pumpAndSettle();
      await stepThrough(settle: true);
      expect(find.text(l10n.shareFileUnreadable), findsOneWidget);

      final segment = find.text(l10n.shareAddToTask);
      tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(ShareSheet),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(segment);
      await tester.pumpAndSettle();
      await stepThrough(settle: true);
      final task = find.textContaining('Task 2 ');
      final list =
          tester
              .state<ScrollableState>(
                find
                    .descendant(
                      of: find.byType(ShareSheet),
                      matching: find.byType(Scrollable),
                    )
                    .first,
              )
              .position
            ..jumpTo(0);
      await tester.pumpAndSettle();
      while (task.evaluate().isEmpty && list.extentAfter > 0) {
        list.jumpTo(list.pixels + 100);
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(task.first);
      await tester.pumpAndSettle();
      await tester.tap(task.first);
      await tester.pumpAndSettle();
      await stepThrough(settle: true);
    });

    testWidgets('task relations, adding one and following at 200 % in '
        'dark mode (${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final data = richData();
      final l10n = lookupAppLocalizations(locale);
      final tasks = data.tasks.all;
      Task bare(Task task) => task.copyWith(relatedTasks: const {});
      data.tasks.all = [
        tasks[0].copyWith(
          relatedTasks: {
            TaskRelationKind.parentTask: [bare(tasks[5])],
            TaskRelationKind.subtask: [bare(tasks[1]), bare(tasks[2])],
            TaskRelationKind.duplicates: [bare(tasks[3])],
            TaskRelationKind.copiedFrom: [bare(tasks[4])],
          },
        ),
        ...tasks.skip(1),
      ];
      data.details.detailsByTask[1] = const TaskDetails(
        subscription: Subscription(
          entity: SubscriptionEntity.project,
          entityId: 1,
        ),
      );
      await pumpSignedInApp(tester, sync: data);

      await tapRow(tester, 'Task 1 ');
      expect(find.byType(TaskDetailSheet), findsOneWidget);
      await scrollToEnd(tester, find.byType(TaskDetailSheet));
      expect(tester.takeException(), isNull);

      await tester.tap(find.text(l10n.taskDetailAddRelation));
      await tester.pumpAndSettle();
      expect(find.byType(AddRelationSheet), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AddRelationSheet),
          matching: find.text(l10n.taskRelationRelated),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(l10n.taskRelationDuplicates).last);
      await tester.pumpAndSettle();
      await scrollToEnd(tester, find.byType(AddRelationSheet));
      expect(tester.takeException(), isNull);
    });

    testWidgets('following a project from its menu at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      await pumpSignedInApp(tester, sync: richData());
      containerOf(tester).read(appRouterProvider).go(AppRoutes.project(2));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(l10n.moreActions));
      await tester.pumpAndSettle();
      expect(find.text(l10n.followProject), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Below the project's other actions, which fill the screen.
      await tester.ensureVisible(find.text(l10n.followProject));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.followProject));
      await tester.pumpAndSettle();
      expect(find.text(l10n.projectFollowed), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('new project sheet with its parent picker at 200 % in dark '
        'mode (${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      await pumpSignedInApp(tester, sync: richData());
      await openTab(tester, l10n.tabProjects);

      await tester.tap(find.byTooltip(l10n.projectNew));
      await tester.pumpAndSettle();
      expect(find.byType(NewProjectSheet), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(NewProjectSheet),
          matching: find.byType(TextField),
        ),
        'A new project with a title long enough to wrap',
      );
      await tester.pumpAndSettle();
      await scrollToEnd(tester, find.byType(NewProjectSheet));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text(l10n.projectParentLabel).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.projectParentLabel).first);
      await tester.pumpAndSettle();
      expect(find.text(l10n.projectParentTopLevel), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('project menu with its confirmations and the duplicate sheet '
        'at 200 % in dark mode (${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      final data = richData();
      await pumpSignedInApp(tester, sync: data);
      containerOf(tester).read(appRouterProvider).go(AppRoutes.project(1));
      await tester.pumpAndSettle();

      Future<void> choose(String item) async {
        await tester.tap(find.byTooltip(l10n.moreActions));
        await tester.pumpAndSettle();
        // The menu's own scroll view, on top of the page's.
        await tester.scrollUntilVisible(
          find.text(item),
          100,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text(item));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byTooltip(l10n.moreActions));
      await tester.pumpAndSettle();
      expect(find.text(l10n.projectEdit), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await choose(l10n.projectDelete);
      expect(
        find.textContaining(l10n.projectDeleteCannotBeUndone),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();

      await choose(l10n.projectArchive);
      expect(find.text(l10n.projectArchiveBody), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();

      await choose(l10n.projectDuplicate);
      expect(find.byType(DuplicateProjectSheet), findsOneWidget);
      await scrollToEnd(tester, find.byType(DuplicateProjectSheet));
      expect(tester.takeException(), isNull);
    });

    testWidgets('project edit page at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final data = richData();
      data.projects.all = [
        for (final project in data.projects.all)
          if (project.id == 1)
            copyProject(project, identifier: 'LONGIDENT')
          else
            project,
      ];
      await pumpSignedInApp(tester, sync: data);
      final router = containerOf(tester).read(appRouterProvider)
        ..go(AppRoutes.project(1));
      await tester.pumpAndSettle();
      unawaited(router.push(AppRoutes.projectEdit(1)));
      await tester.pumpAndSettle();

      expect(find.byType(ProjectEditPage), findsOneWidget);
      await scrollToEnd(tester, find.byType(ListView));
      expect(tester.takeException(), isNull);
    });

    testWidgets('description editor with its toolbar, menus, mention '
        'suggestions, link sheet and dialogs at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      final bridges = FakeEditorBridges();
      final data = richData();
      await pumpSignedInApp(
        tester,
        sync: data,
        overrides: [
          bridges.override,
          userRepositoryProvider.overrideWithValue(
            FakeUserRepository(
              projectUsers: const {
                1: [
                  User(
                    id: 1,
                    username: 'maximiliane',
                    name: 'Maximiliane Musterfrau-Beispielhausen',
                  ),
                ],
              },
            ),
          ),
        ],
      );
      final router = containerOf(tester).read(appRouterProvider);
      unawaited(router.push(AppRoutes.taskDescription(1)));
      await tester.pumpAndSettle();
      expect(find.byType(DescriptionEditorPage), findsOneWidget);

      final bridge = bridges.last
        ..edit(
          '<p>Edited</p>',
          active: const EditorActive(bold: true, heading: 2, table: true),
        );
      await tester.pumpAndSettle();
      final toolbar = find.byType(EditorToolbar);
      for (var i = 0; i < 10; i++) {
        await tester.drag(toolbar, const Offset(-300, 0));
        await tester.pumpAndSettle();
      }
      for (final tooltip in [
        l10n.editorTable,
        l10n.editorImage,
        l10n.editorTextStyle,
      ]) {
        await tester.ensureVisible(find.byTooltip(tooltip));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(tooltip));
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();
      }

      bridge.emit(const MentionQuery('max'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.byType(MentionBar), findsOneWidget);
      bridge.emit(const MentionEnd());
      await tester.pumpAndSettle();

      bridge.emit(
        const EditorStateChanged(
          EditorState(
            dirty: true,
            active: EditorActive(
              link: true,
              linkHref: 'https://example.org/a/rather/long/link',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip(l10n.editorLink));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(l10n.editorLink));
      await tester.pumpAndSettle();
      expect(find.text(l10n.editorLinkRemove), findsOneWidget);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text(l10n.descriptionEditorLeaveTitle), findsOneWidget);
      await tester.tap(find.text(l10n.taskEditKeepEditing));
      await tester.pumpAndSettle();

      data.tasks.all = [
        for (final task in data.tasks.all)
          if (task.id == 1)
            task.copyWith(description: '<p>Changed on the web</p>')
          else
            task,
      ];
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, l10n.taskEditSave));
      await tester.pumpAndSettle();
      expect(find.text(l10n.descriptionEditorChangedTitle), findsOneWidget);
      await tester.tap(find.text(l10n.taskEditKeepEditing));
      await tester.pumpAndSettle();

      bridge.emit(const EditorStopped());
      await tester.pumpAndSettle();
      expect(find.text(l10n.descriptionEditorStoppedKept), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a description conflict compared at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final now = DateTime.now().toUtc();
      final l10n = lookupAppLocalizations(locale);
      final data = SyncFakes(now: now);
      data.tasks
        ..all = [
          sampleTask(
            id: 1,
            title: 'A task with a rather long title to wrap',
            description: '<p>Mine, written offline</p>',
          ),
        ]
        ..webDescriptions[1] = [
          '<h2>From the web</h2><ul data-type="taskList">',
          '<li data-checked="true" data-type="taskItem"><label>',
          '<input type="checkbox" checked="checked"><span></span></label>',
          '<div><p>A checked item with some text</p></div></li></ul>',
        ].join()
        ..syncProblems = [
          SyncProblem(
            operationId: 'op-1',
            kind: OutboxOperationKind.updateTask,
            taskId: 1,
            taskTitle: 'A task with a rather long title to wrap',
            failure: const DescriptionConflict(),
            failedAt: now.subtract(const Duration(minutes: 5)),
            changes: const TaskChanges(
              description: '<p>Mine, written offline</p>',
              descriptionBase: '<p>Before</p>',
            ),
          ),
        ]
        ..pendingChanges = 1;
      await pumpSignedInApp(tester, sync: data);
      await openTab(tester, l10n.tabAccount);

      await tester.scrollUntilVisible(
        find.text(l10n.syncProblemCompare),
        100,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(find.text(l10n.syncProblemCompare));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.syncProblemCompare));
      await tester.pumpAndSettle();
      expect(find.text(l10n.syncProblemCompareTitle), findsOneWidget);
      await scrollToEnd(tester, find.byType(DescriptionConflictSheet));
      expect(find.text(l10n.syncProblemKeepMine), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('views page and the view form at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      final data = richData();
      data.projects.all = [
        for (final project in data.projects.all)
          if (project.id == 1)
            copyProject(
              project,
              views: [
                ...defaultViews(1, firstViewId: 10),
                sampleListView(
                  id: 14,
                  projectId: 1,
                  title: 'A view with a rather long title of its own',
                  position: 500,
                  filter: 'done = false && priority >= 3',
                ),
              ],
            )
          else
            project,
      ];
      await pumpSignedInApp(tester, sync: data);
      final router = containerOf(tester).read(appRouterProvider)
        ..go(AppRoutes.project(1));
      await tester.pumpAndSettle();
      unawaited(router.push(AppRoutes.projectViews(1)));
      await tester.pumpAndSettle();

      expect(find.byType(ProjectViewsPage), findsOneWidget);
      await scrollToEnd(tester, find.byType(ListView));
      expect(tester.takeException(), isNull);

      await tester.tap(
        find.byTooltip(
          l10n.projectViewOptionsFor(
            'A view with a rather long title of its own',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.moveUp), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(
          ListTile,
          'A view with a rather long title of its own',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ViewFormSheet), findsOneWidget);
      await scrollToEnd(tester, find.byType(ViewFormSheet));
      expect(tester.takeException(), isNull);
      await tester.enterText(
        find.descendant(
          of: find.byType(FilterField),
          matching: find.byType(TextField),
        ),
        'priority >= 3 && due',
      );
      await tester.pumpAndSettle();
      expect(find.byType(ActionChip), findsWidgets);
      await scrollToEnd(tester, find.byType(ViewFormSheet));
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(ViewFormSheet), findsNothing);
      final kanban = find
          .widgetWithText(ListTile, l10n.projectViewKanban)
          .first;
      await tester.ensureVisible(kanban);
      await tester.pumpAndSettle();
      await tester.tap(kanban);
      await tester.pumpAndSettle();
      await scrollToEnd(tester, find.byType(ViewFormSheet));
      await tester.tap(find.text(l10n.projectViewColumnsLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.projectViewColumnsFilter).last);
      await tester.pumpAndSettle();
      await scrollToEnd(tester, find.byType(ViewFormSheet));
      expect(find.text(l10n.projectViewFilterColumnsOnWeb), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('task edit page with its pickers at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      await pumpSignedInApp(tester, sync: richData());
      final l10n = lookupAppLocalizations(locale);
      await tapRow(tester, 'Task 1 ');
      await tester.tap(find.byTooltip(l10n.taskEdit));
      await tester.pumpAndSettle();

      expect(find.byType(TaskEditPage), findsOneWidget);
      await scrollToEnd(tester, find.byType(ListView));
      expect(tester.takeException(), isNull);

      // The end of the list is built now; the top is not, so jump back.
      await tester.tap(find.text(l10n.repeatModeFromCompletion));
      await tester.pumpAndSettle();
      tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(ListTile, l10n.taskEditProject),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, l10n.taskEditProject));
      await tester.pumpAndSettle();
      expect(find.text(l10n.taskEditProjectPickerTitle), findsOneWidget);
      await tester.tap(find.text(l10n.taskEditProjectPickerTitle));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(l10n.taskEditDiscardTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('new task sheet at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final data = richData();
      final project = data.projects.all.first;
      final label = sampleLabel(
        id: 1,
        title: 'A rather long label title',
        hexColor: 'ffeb10',
      );
      const person = User(
        id: 1,
        username: 'maximiliane',
        name: 'Maximiliane Musterfrau-Beispielhausen',
      );
      final service = FakeQuickAddService(
        planner: (line, {fallbackProjectId, fallbackDueDate}) {
          final parsed = parseTaskText(line, now: DateTime.now());
          return QuickAddPlan(
            input: line,
            parsed: parsed,
            title: parsed.text,
            project: project,
            unmatchedProject: parsed.project,
            labels: [label],
            newLabels: const ['ein ziemlich langes neues Label'],
            assignees: const [person],
            unresolvedAssignees: const ['jemand-mit-langem-namen'],
            dueDate: parsed.date?.toUtc(),
            repeat: parsed.repeats,
            priority: parsed.priority,
            reminders: const [
              TaskReminder(
                relativePeriod: Duration(days: -2),
                relativeTo: ReminderRelativeTo.dueDate,
              ),
            ],
          );
        },
      );
      await pumpSignedInApp(
        tester,
        sync: data,
        overrides: [
          quickAddServiceProvider.overrideWithValue(service),
          labelRepositoryProvider.overrideWithValue(
            FakeLabelRepository(labels: [label]),
          ),
          userRepositoryProvider.overrideWithValue(
            FakeUserRepository(known: const [person]),
          ),
        ],
      );
      final l10n = lookupAppLocalizations(locale);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.byType(NewTaskSheet), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'A new task');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(l10n.shortcutTomorrow));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.shortcutTomorrow));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.enterText(
        find.byType(TextField),
        'A new task with a long title *"A rather long label title" '
        '+Unbekannt @maximiliane !5 tomorrow at 9:00 every 2 weeks\n'
        'A second line *a',
      );
      await tester.pumpAndSettle();
      expect(find.byType(MagicSuggestions), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip(l10n.quickAddHelp));
      await tester.pumpAndSettle();
      await scrollToEnd(tester, find.byType(QuickAddHelpSheet));
      expect(tester.takeException(), isNull);
    });

    testWidgets('label, people and reminder pickers at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      const longName = User(
        id: 2,
        username: 'konstantin',
        name: 'Konstantin Langername-Mustermann',
      );
      await pumpSignedInApp(
        tester,
        sync: richData(),
        overrides: [
          labelRepositoryProvider.overrideWithValue(
            FakeLabelRepository(
              labels: [
                sampleLabel(
                  id: 1,
                  title: 'A rather long label title',
                  hexColor: 'ffeb10',
                ),
                sampleLabel(id: 2, title: 'Another label that goes on'),
              ],
            ),
          ),
          userRepositoryProvider.overrideWithValue(
            FakeUserRepository(
              projectUsers: {
                1: const [longName],
              },
            ),
          ),
        ],
      );
      final l10n = lookupAppLocalizations(locale);
      await tapRow(tester, 'Task 1 ');
      await tester.tap(find.byTooltip(l10n.taskEdit));
      await tester.pumpAndSettle();

      Future<void> open(String action) async {
        // The form builds lazily; at this scale the sections start below
        // the fold.
        await tester.scrollUntilVisible(
          find.text(action),
          200,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
      }

      Future<void> close() async {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }

      await open(l10n.taskEditAddLabel);
      await tester.enterText(find.byType(TextField).last, 'A new label');
      await tester.pumpAndSettle();
      expect(find.text(l10n.labelPickerCreate('A new label')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await close();

      await open(l10n.taskEditAssign);
      await tester.scrollUntilVisible(
        find.text(longName.name),
        200,
        scrollable: find
            .descendant(
              of: find.byType(AssigneePicker),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text(longName.name), findsOneWidget);
      expect(tester.takeException(), isNull);
      await close();

      await open(l10n.taskEditAddReminder);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text(l10n.reminderPickerCustom));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.reminderPickerCustom));
      await tester.pumpAndSettle();
      expect(find.text(l10n.reminderPickerCustomTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
      await close();
      expect(find.byType(TaskEditPage), findsOneWidget);
    });

    // The keyboard takes most of the height in landscape or at a large text
    // size; the search field and the notices scroll with the rows.
    for (final (name, size, keyboard, textScale) in const [
      ('landscape', Size(740, 360), 200.0, 1.0),
      ('portrait at 200 %', Size(360, 740), 300.0, 2.0),
      ('small portrait at 200 %', Size(320, 640), 260.0, 2.0),
    ]) {
      testWidgets(
        'label and people pickers with the keyboard up, offline, '
        '$name (${locale.languageCode})',
        (tester) async {
          useLocale(tester, locale);
          tester.platformDispatcher.textScaleFactorTestValue = textScale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final now = DateTime(2026, 10, 10, 12);
          const longName = User(
            id: 2,
            username: 'konstantin',
            name: 'Konstantin Langername-Mustermann',
          );
          final label = sampleLabel(id: 1, title: 'A rather long label title');
          final data = SyncFakes(now: now);
          data.projects.all = [sampleProject(id: 1, title: 'Work')];
          data.tasks.all = [
            sampleTask(
              id: 1,
              title: 'Task 1',
              labels: [label],
              assignees: const [longName],
            ),
          ];
          await openEditPageWith(
            tester,
            data: data,
            taskId: 1,
            now: now,
            size: size,
            labels: FakeLabelRepository(labels: [label]),
            users: FakeUserRepository(
              known: const [longName],
            )..searchFailure = const NetworkFailure(NetworkProblem.unreachable),
          );
          final l10n = lookupAppLocalizations(locale);

          Future<void> openWithKeyboard(String action) async {
            await tapVisible(tester, find.text(action));
            tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }

          Future<void> close() async {
            tester.view.resetViewInsets();
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
          }

          await openWithKeyboard(l10n.taskEditAddLabel);
          await tester.enterText(find.byType(TextField).last, 'A new label');
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await close();

          await openWithKeyboard(l10n.taskEditAssign);
          final list = find
              .descendant(
                of: find.byType(AssigneePicker),
                matching: find.byType(Scrollable),
              )
              .first;
          // Jumps rather than drags: on iOS a drag that starts on the
          // search field selects text instead of scrolling.
          final position = tester.state<ScrollableState>(list).position;
          for (final text in [l10n.assigneePickerOffline, longName.name]) {
            final row = find.descendant(of: list, matching: find.text(text));
            while (row.evaluate().isEmpty &&
                position.pixels < position.maxScrollExtent) {
              position.jumpTo(
                (position.pixels + 40).clamp(0, position.maxScrollExtent),
              );
              await tester.pump();
            }
            expect(row, findsOneWidget);
          }
          expect(tester.takeException(), isNull);
          await close();
        },
        variant: const TargetPlatformVariant({
          TargetPlatform.android,
          TargetPlatform.iOS,
        }),
      );
    }

    // The comment field stays above the keyboard however little room that
    // leaves: what is above the field scrolls and the list gives way.
    for (final (name, size, keyboard, textScale) in const [
      ('landscape', Size(740, 360), 200.0, 1.0),
      ('portrait at 200 %', Size(360, 740), 300.0, 2.0),
      ('small portrait at 200 %', Size(320, 640), 260.0, 2.0),
    ]) {
      testWidgets(
        'the comment field replying, with suggestions and the keyboard up, '
        '$name (${locale.languageCode})',
        (tester) async {
          usePhoneSurface(tester, logicalSize: size);
          useLocale(tester, locale);
          tester.platformDispatcher.textScaleFactorTestValue = textScale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final l10n = lookupAppLocalizations(locale);
          const maxi = User(
            id: 1,
            username: 'maximiliane',
            name: 'Maximiliane Musterfrau-Beispielhausen',
          );
          final data = SyncFakes(now: DateTime(2026, 10, 10, 12));
          data.projects.all = [sampleProject(id: 1, title: 'Work')];
          data.tasks.all = [sampleTask(id: 1, title: 'Task 1')];
          data.details
            ..detailsByTask[1] = const TaskDetails(
              commentCount: 1,
              maxPermission: Permission.write,
            )
            ..commentsByTask[1] = [
              sampleComment(
                id: 1,
                author: maxi,
                html: '<p>A comment long enough to fill the reply quote</p>',
              ),
            ];
          await pumpSignedInApp(
            tester,
            sync: data,
            overrides: [
              userRepositoryProvider.overrideWithValue(
                FakeUserRepository(
                  projectUsers: {
                    1: [maxi],
                  },
                ),
              ),
            ],
          );
          unawaited(
            showTaskDetail(
              containerOf(tester)
                  .read(appRouterProvider)
                  .routerDelegate
                  .navigatorKey
                  .currentContext!,
              task: data.tasks.find(1)!,
            ),
          );
          await tester.pumpAndSettle();
          final field = find.descendant(
            of: find.byType(CommentComposer),
            matching: find.byType(TextField),
          );

          Future<void> expectFieldAboveKeyboard() async {
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              tester.getRect(field).bottom,
              lessThanOrEqualTo(size.height - keyboard + 0.5),
            );
          }

          final sheetList = find
              .descendant(
                of: find.byType(TaskDetailSheet),
                matching: find.byType(Scrollable),
              )
              .first;
          await tester.scrollUntilVisible(
            find.text(l10n.taskDetailShowComments),
            100,
            scrollable: sheetList,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.taskDetailShowComments));
          await tester.pumpAndSettle();
          final menu = find.byTooltip(l10n.commentOptions(maxi.name));
          await tester.scrollUntilVisible(menu, 100, scrollable: sheetList);
          await tester.pumpAndSettle();
          await tester.tap(menu);
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.commentReply));
          await tester.pumpAndSettle();

          tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);
          addTearDown(tester.view.resetViewInsets);
          await expectFieldAboveKeyboard();
          expect(find.text(l10n.commentReplyingTo(maxi.name)), findsOneWidget);

          await tester.enterText(field, 'Hallo @Ma');
          await tester.pump(const Duration(milliseconds: 400));
          await expectFieldAboveKeyboard();
          expect(find.byType(MentionBar), findsOneWidget);
        },
        variant: const TargetPlatformVariant({
          TargetPlatform.android,
          TargetPlatform.iOS,
        }),
      );
    }

    for (final (name, size) in const [
      ('on a small phone', Size(320, 640)),
      ('beside the rail on a phone in landscape', Size(740, 360)),
      ('on a tablet in landscape', Size(1280, 800)),
    ]) {
      testWidgets('a kanban board $name at 200 % in dark mode '
          '(${locale.languageCode})', (tester) async {
        usePhoneSurface(tester, logicalSize: size);
        useAccessibilityExtremes(tester);
        useLocale(tester, locale);
        await pumpSignedInApp(tester, sync: kanbanData());
        containerOf(tester).read(appRouterProvider).go(AppRoutes.project(1));
        await tester.pumpAndSettle();

        expect(find.byType(BoardColumnView), findsNWidgets(4));
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await scrollToEnd(tester, find.byType(BoardColumnView).first);
        expect(tester.takeException(), isNull);

        final board = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.descendant(
                  of: find.byType(ProjectBoard),
                  matching: find.byType(SingleChildScrollView),
                ),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        for (var i = 0; i < 20 && board.position.extentAfter > 0; i++) {
          board.position.jumpTo(
            (board.position.pixels + 300).clamp(
              0,
              board.position.maxScrollExtent,
            ),
          );
          await tester.pumpAndSettle();
        }
        expect(board.position.extentAfter, 0);
        expect(find.text('Empty'), findsOneWidget);
        expect(
          tester.getRect(find.byType(NewColumnTile)).right,
          lessThanOrEqualTo(size.width),
        );
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      });
    }

    testWidgets(
      "a kanban column's menu, sheets and delete confirmation at 200 % in "
      'dark mode with the keyboard up (${locale.languageCode})',
      (tester) async {
        useWorstCase(tester, locale);
        final l10n = lookupAppLocalizations(locale);
        await pumpSignedInApp(tester, sync: kanbanData());
        containerOf(tester).read(appRouterProvider).go(AppRoutes.project(1));
        await tester.pumpAndSettle();

        Future<void> openMenu() async {
          await tester.tap(
            find.byTooltip(
              l10n.boardColumnOptionsFor(
                'A column whose title is long enough to wrap twice',
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        Future<void> choose(String item) async {
          final entry = find
              .ancestor(
                of: find.text(item),
                matching: find.byWidgetPredicate(
                  (widget) => widget is PopupMenuItem,
                ),
              )
              .first;
          await tester.ensureVisible(entry);
          await tester.pumpAndSettle();
          await tester.tap(entry);
          await tester.pumpAndSettle();
        }

        Future<void> withKeyboard() async {
          tester.view.viewInsets = const FakeViewPadding(bottom: 260 * 3);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        Future<void> closeSheet() async {
          tester.view.resetViewInsets();
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        }

        await openMenu();
        expect(find.text(l10n.boardDefaultColumnHint), findsOneWidget);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await tester.ensureVisible(find.text(l10n.boardColumnDelete));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await choose(l10n.boardColumnLimit(l10n.boardColumnLimitNotSet));
        await withKeyboard();
        await tester.enterText(find.byType(TextField), '3');
        await tester.pumpAndSettle();
        expect(find.text(l10n.boardColumnLimitBelowCount), findsOneWidget);
        expect(tester.takeException(), isNull);
        await closeSheet();

        await openMenu();
        await choose(l10n.boardColumnRename);
        await withKeyboard();
        await tester.enterText(find.byType(TextField), '');
        await tester.pumpAndSettle();
        expect(find.text(l10n.boardColumnTitleEmpty), findsOneWidget);
        expect(tester.takeException(), isNull);
        await closeSheet();

        await openMenu();
        await choose(l10n.boardColumnDelete);
        expect(find.text(l10n.boardDeleteColumnTitle), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(l10n.cancel));
        await tester.pumpAndSettle();

        final board = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.descendant(
                  of: find.byType(ProjectBoard),
                  matching: find.byType(SingleChildScrollView),
                ),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        board.position.jumpTo(board.position.maxScrollExtent);
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.boardCreateColumn));
        await tester.pumpAndSettle();
        await withKeyboard();
        expect(find.text(l10n.boardNewColumn), findsOneWidget);
        await closeSheet();
        expect(tester.takeException(), isNull);
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );

    for (final archived in [false, true]) {
      testWidgets(
        'in landscape the columns of ${archived ? 'an archived' : 'a'} '
        "project's board end above the tab bar, or at the screen's bottom "
        'beside the rail, at 200 % in dark mode (${locale.languageCode})',
        (tester) async {
          final apple = defaultTargetPlatform == TargetPlatform.iOS;
          final size = apple ? const Size(844, 390) : const Size(740, 360);
          usePhoneSurface(tester, logicalSize: size);
          if (apple) {
            tester.view.padding = const FakeViewPadding(
              left: 47 * 3,
              right: 47 * 3,
              bottom: 21 * 3,
            );
            addTearDown(tester.view.resetPadding);
          }
          useAccessibilityExtremes(tester);
          useLocale(tester, locale);
          await pumpSignedInApp(tester, sync: kanbanData(archived: archived));
          containerOf(tester).read(appRouterProvider).go(AppRoutes.project(1));
          await tester.pumpAndSettle();

          final visibleBottom = apple
              ? tester.getRect(find.byType(AdaptiveNavigationBar)).top
              : size.height;
          for (final column in find.byType(BoardColumnView).evaluate()) {
            expect(
              tester
                  .getRect(find.byElementPredicate((e) => e == column))
                  .bottom,
              lessThanOrEqualTo(visibleBottom),
            );
          }
          expect(tester.takeException(), isNull);
        },
        variant: const TargetPlatformVariant({
          TargetPlatform.android,
          TargetPlatform.iOS,
        }),
      );
    }

    testWidgets('project tree and project tasks at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      await pumpSignedInApp(tester, sync: richData());
      final l10n = lookupAppLocalizations(locale);

      await openTab(tester, l10n.tabProjects);
      await scrollToEnd(tester, find.byType(CustomScrollView));
      expect(tester.takeException(), isNull);

      containerOf(tester).read(appRouterProvider).go(AppRoutes.project(1));
      await tester.pumpAndSettle();
      await scrollToEnd(tester, find.byType(CustomScrollView));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a list and the project tree put in order by dragging and '
        'by the screen reader actions at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      const work = 'Work with a very long project title';
      const child = 'Child project with another long title';
      final data = richData();
      data.projects.all = [
        sampleProject(
          id: 1,
          title: work,
          position: 100,
          views: [sampleListView(id: 11, projectId: 1)],
        ),
        sampleProject(id: 2, title: child, parent: 1, position: 10),
        sampleProject(
          id: 3,
          title: 'Another project with a long title',
          position: 200,
        ),
      ];
      data.tasks.setSnapshot(
        'view:11',
        ListSnapshot(
          positions: {for (var id = 1; id <= 6; id++) id: id * 100.0},
          loadedAt: DateTime.now(),
        ),
      );
      data.projects.moveFailure = const Forbidden(code: 1);
      await pumpSignedInApp(tester, sync: data);
      final l10n = lookupAppLocalizations(locale);

      List<String> actionsOf(Finder finder) => [
        for (final id
            in tester
                    .getSemantics(finder)
                    .getSemanticsData()
                    .customSemanticsActionIds ??
                const <int>[])
          CustomSemanticsAction.getAction(id)!.label!,
      ];

      Future<void> hold(Finder row) async {
        final gesture = await tester.startGesture(
          tester.getTopLeft(row) + const Offset(60, 24),
        );
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byType(LiftedRows), findsOneWidget);
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump();
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      containerOf(tester).read(appRouterProvider).go(AppRoutes.project(1));
      await tester.pumpAndSettle();
      final firstTask = find.textContaining('Task 1 ');
      expect(actionsOf(firstTask), [l10n.moveDown]);
      await hold(find.ancestor(of: firstTask, matching: find.byType(TaskRow)));

      await openTab(tester, l10n.tabProjects);
      final childRow = find.ancestor(
        of: find.text(child),
        matching: find.byType(ProjectRow),
      );
      await tester.scrollUntilVisible(
        find.text(child),
        200,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(
        actionsOf(find.text(child)),
        unorderedEquals([l10n.projectMoveOut(work)]),
      );
      await hold(childRow);

      final node = tester.getSemantics(find.text(child));
      node.owner!.performAction(
        node.id,
        SemanticsAction.customAction,
        CustomSemanticsAction.getIdentifier(
          CustomSemanticsAction(label: l10n.projectMoveOut(work)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.projectMoveAdminOnly), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final (name, size) in const [
      ('above the bar on a small phone', Size(320, 640)),
      ('beside the rail on a phone in landscape', Size(740, 360)),
    ]) {
      testWidgets('the offline banner $name, with every tab, at 200 % in '
          'dark mode (${locale.languageCode})', (tester) async {
        usePhoneSurface(tester, logicalSize: size);
        useAccessibilityExtremes(tester);
        useLocale(tester, locale);
        final now = DateTime.now();
        final data = richData(
          status: SyncFailed(
            failure: const NetworkFailure(NetworkProblem.unreachable),
            lastSyncedAt: now.subtract(const Duration(days: 3)),
          ),
        );
        data.engine.onRefresh = () async =>
            throw const NetworkFailure(NetworkProblem.unreachable);
        await pumpSignedInApp(tester, sync: data);
        final l10n = lookupAppLocalizations(locale);

        expect(
          find.textContaining(l10n.offlineNotice, findRichText: true),
          findsOneWidget,
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await scrollToEnd(tester, find.byType(CustomScrollView));
        expect(tester.takeException(), isNull);
        for (final tab in [
          l10n.tabUpcoming,
          l10n.tabProjects,
          l10n.tabAccount,
        ]) {
          await openTab(tester, tab);
          expect(tester.takeException(), isNull);
        }
        await scrollToEnd(tester, find.byType(ListView));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('projects tab sections with archived projects, a saved '
        'filter and the Favorites list at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final data = richData();
      data.projects.all = [
        ...data.projects.all,
        sampleProject(
          id: 3,
          title: 'An archived project with a long title',
          archived: true,
        ),
      ];
      data.projects.savedFilters = const [
        SavedFilterRef(
          projectId: -2,
          title: 'A saved filter with a rather long title',
          isFavorite: true,
        ),
        SavedFilterRef(projectId: -3, title: 'My Open Tasks'),
      ];
      data.listPreferences.setProjectTree(
        const ProjectTreePreferences(showArchived: true),
      );
      data.tasks.setSavedFilterSnapshot(
        -2,
        ListSnapshot(
          positions: const {1: 0, 2: 1, 6: 2},
          loadedAt: DateTime.now(),
        ),
      );
      await pumpSignedInApp(tester, sync: data);
      final l10n = lookupAppLocalizations(locale);

      await openTab(tester, l10n.tabProjects);
      await scrollToEnd(tester, find.byType(CustomScrollView));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip(l10n.moreActions));
      await tester.pumpAndSettle();
      expect(find.text(l10n.projectsShowArchived), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      containerOf(tester).read(appRouterProvider).go(AppRoutes.project(3));
      await tester.pumpAndSettle();
      expect(find.text(l10n.projectArchivedNote), findsOneWidget);
      await scrollToEnd(tester, find.byType(CustomScrollView));
      expect(tester.takeException(), isNull);

      containerOf(tester).read(appRouterProvider).go(AppRoutes.project(-2));
      await tester.pumpAndSettle();
      await scrollToEnd(tester, find.byType(CustomScrollView));
      expect(tester.takeException(), isNull);

      // Never downloaded: the download the fake answers with nothing.
      containerOf(tester).read(appRouterProvider).go(AppRoutes.project(-3));
      await tester.pumpAndSettle();
      expect(find.text(l10n.smartListFilterDownloadingTitle), findsOneWidget);
      expect(tester.takeException(), isNull);

      containerOf(tester)
          .read(appRouterProvider)
          .go(AppRoutes.project(Project.favoritesId));
      await tester.pumpAndSettle();
      await scrollToEnd(tester, find.byType(CustomScrollView));
      expect(tester.takeException(), isNull);
    });

    testWidgets('search with every kind of result and a label opened at '
        '200 % in dark mode (${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final data = richData();
      final label = sampleLabel(
        id: 1,
        title: 'A rather long label title',
        hexColor: 'ffeb10',
      );
      data.search.labels = [label];
      data.projects.savedFilters = const [
        SavedFilterRef(
          projectId: -2,
          title: 'Task lists with a rather long saved filter title',
        ),
      ];
      data.projects.all = [
        ...data.projects.all,
        sampleProject(id: 3, title: 'Tasks for a project with a long title'),
      ];
      await pumpSignedInApp(
        tester,
        sync: data,
        overrides: [
          labelRepositoryProvider.overrideWithValue(
            FakeLabelRepository(labels: [label]),
          ),
        ],
      );
      final l10n = lookupAppLocalizations(locale);

      await tester.tap(find.byType(SearchPill));
      await tester.pumpAndSettle();
      expect(find.text(l10n.searchStartTitle), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.enterText(find.byType(TextField), 'ti');
      await tester.pumpAndSettle();
      await scrollToEnd(tester, find.byType(CustomScrollView));
      expect(find.text('A rather long label title'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('A rather long label title'));
      await tester.pumpAndSettle();
      await scrollToEnd(tester, find.byType(CustomScrollView));
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'nothing like this');
      await tester.pumpAndSettle();
      expect(find.text(l10n.searchNoResultsTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('saved filter form with the filter builder, its suggestions '
        'and its error at 200 % in dark mode (${locale.languageCode})', (
      tester,
    ) async {
      useWorstCase(tester, locale);
      final data = richData();
      data.search.matchCount = 1234;
      await pumpSignedInApp(
        tester,
        sync: data,
        overrides: [
          labelRepositoryProvider.overrideWithValue(
            FakeLabelRepository(
              labels: [
                sampleLabel(id: 1, title: 'A rather long label title'),
                sampleLabel(id: 2, title: 'Another long label title'),
              ],
            ),
          ),
          userRepositoryProvider.overrideWithValue(FakeUserRepository()),
        ],
      );
      final l10n = lookupAppLocalizations(locale);
      final router = containerOf(tester).read(appRouterProvider)
        ..go(AppRoutes.projects);
      await tester.pumpAndSettle();
      unawaited(router.push(AppRoutes.savedFilterNew));
      await tester.pumpAndSettle();
      expect(find.byType(SavedFilterFormPage), findsOneWidget);

      final filter = find.descendant(
        of: find.byType(FilterField),
        matching: find.byType(TextField),
      );
      await tester.enterText(filter, 'done = false ');
      await tester.pump(FilterField.countDelay);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ActionChip, '&&'), findsOneWidget);
      expect(find.text(l10n.filterMatchCount(1234)), findsOneWidget);
      await scrollToEnd(tester, find.byType(ListView));
      expect(tester.takeException(), isNull);

      await tester.dragUntilVisible(
        filter,
        find.byType(ListView),
        const Offset(0, 200),
      );
      // Scrolled out of sight and back, the field kept what was typed.
      expect(
        tester.widget<TextField>(filter).controller!.text,
        'done = false ',
      );
      await tester.enterText(filter, 'labels in ');
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(ActionChip, 'A rather long label title'),
        findsOneWidget,
      );
      await scrollToEnd(tester, find.byType(ListView));
      expect(tester.takeException(), isNull);

      await tester.dragUntilVisible(
        filter,
        find.byType(ListView),
        const Offset(0, 200),
      );
      await tester.enterText(filter, 'dueDat < now && (done = true');
      await tester.pumpAndSettle();
      await scrollToEnd(tester, find.byType(ListView));
      expect(tester.takeException(), isNull);
    });

    testWidgets("a saved filter's list with its menu, confirmation and edit "
        'form at 200 % in dark mode (${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final data = richData();
      const title = 'A saved filter with a rather long title';
      data.projects.savedFilters = const [
        SavedFilterRef(
          projectId: -2,
          title: title,
          description: 'A description that is long enough to wrap twice.',
          definition: SavedFilterDefinition(
            filter: ViewFilter(filter: 'done = false && priority >= 3'),
          ),
        ),
      ];
      data.tasks.setSavedFilterMatches(-2, {1, 2, 3});
      await pumpSignedInApp(
        tester,
        sync: data,
        overrides: [
          labelRepositoryProvider.overrideWithValue(FakeLabelRepository()),
          userRepositoryProvider.overrideWithValue(FakeUserRepository()),
        ],
      );
      final l10n = lookupAppLocalizations(locale);
      containerOf(tester).read(appRouterProvider).go(AppRoutes.project(-2));
      await tester.pumpAndSettle();
      await scrollToEnd(tester, find.byType(CustomScrollView));
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip(l10n.moreActions));
      await tester.pumpAndSettle();
      expect(find.text(l10n.projectAddToFavourites), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(l10n.projectDelete));
      await tester.pumpAndSettle();
      expect(find.text(l10n.savedFilterDeleteTitle(title)), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(l10n.moreActions));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.projectEdit));
      await tester.pumpAndSettle();
      expect(find.byType(SavedFilterFormPage), findsOneWidget);
      await scrollToEnd(tester, find.byType(ListView));
      expect(tester.takeException(), isNull);
    });

    testWidgets('upcoming with every section and its sheets at 200 % in '
        'dark mode (${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final data = richData();
      data.listPreferences.setUpcoming(
        const UpcomingPreferences(
          preset: DateRangePreset.restOfThisMonth,
          showWithoutDueDate: true,
        ),
      );
      await pumpSignedInApp(tester, sync: data);
      final l10n = lookupAppLocalizations(locale);

      await openTab(tester, l10n.tabUpcoming);
      await scrollToEnd(tester, find.byType(CustomScrollView));
      expect(tester.takeException(), isNull);

      // The day strip scrolls with the rows; today picked alone.
      tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byType(DayStrip),
              matching: find.byType(InkWell),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip(l10n.upcomingSelectRange));
      await tester.pumpAndSettle();
      await scrollToEnd(tester, find.byType(ListView).last);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(l10n.upcomingRangeCustomEntry));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('upcoming in landscape at 200 % leaves room to read '
        '(${locale.languageCode})', (tester) async {
      const landscape = Size(800, 360);
      usePhoneSurface(tester, logicalSize: landscape);
      useAccessibilityExtremes(tester);
      useLocale(tester, locale);
      await pumpSignedInApp(tester, sync: richData());
      final l10n = lookupAppLocalizations(locale);

      await openTab(tester, l10n.tabUpcoming);

      // The day strip scrolls with the rows rather than above them.
      final list = find.descendant(
        of: find.byType(UpcomingScreen),
        matching: find.byType(CustomScrollView),
      );
      expect(
        tester.getSize(list).height,
        greaterThanOrEqualTo(landscape.height * 0.5),
      );
      expect(
        find.descendant(of: list, matching: find.byType(DayStrip)),
        findsOneWidget,
      );
      await scrollToEnd(tester, list);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a nested project list with views, its sort sheet and the '
        'done part at 200 % in dark mode (${locale.languageCode})', (
      tester,
    ) async {
      useWorstCase(tester, locale);
      final data = richData();
      data.projects.all = [
        sampleProject(
          id: 1,
          title: 'Work with a very long project title',
          views: [
            sampleListView(id: 11, projectId: 1),
            sampleListView(
              id: 12,
              projectId: 1,
              title: 'A view with a rather long title',
              position: 200,
              filter: '',
            ),
            sampleListView(
              id: 13,
              projectId: 1,
              title: 'Filtered',
              position: 300,
              filter: 'priority >= 4 && labels in 3, 4',
            ),
          ],
        ),
        sampleProject(id: 2, title: 'Another long project', hexColor: 'e8445a'),
      ];
      data.tasks.all = [
        ...data.tasks.all,
        for (var level = 0; level <= 5; level++)
          sampleTask(
            id: 100 + level,
            title: 'Subtask level $level with a long title to wrap',
            projectId: level == 3 ? 2 : 1,
            parentIds: [if (level > 0) 99 + level],
            subtaskIds: [if (level < 5) 101 + level],
            assignees: const [
              User(id: 1, username: 'a', name: 'Anna'),
              User(id: 2, username: 'b', name: 'Ben'),
              User(id: 3, username: 'c', name: 'Cleo'),
              User(id: 4, username: 'd', name: 'Dan'),
            ],
            description: [
              '<ul data-type="taskList">',
              '<li data-checked="true">x</li>',
              '<li data-checked="false">y</li>',
              '</ul>',
            ].join(),
            done: level == 2,
          ),
        sampleTask(id: 200, title: 'Done a while ago', done: true),
      ];
      data.tasks.setSnapshot(
        'view:13',
        ListSnapshot(positions: const {1: 1, 2: 2}, loadedAt: DateTime.now()),
      );
      data.listPreferences.setView(
        'view:11',
        const ViewPreferences(showDone: true),
      );
      await pumpSignedInApp(tester, sync: data);
      final l10n = lookupAppLocalizations(locale);

      // Rows four levels deep are narrow and tall at this size: further
      // than [scrollToEnd]'s drags reach.
      Future<void> jumpToEnd() async {
        final position = tester
            .state<ScrollableState>(
              find
                  .descendant(
                    of: find.byType(CustomScrollView),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            )
            .position;
        for (var i = 0; i < 200 && position.extentAfter > 0; i++) {
          position.jumpTo(
            (position.pixels + 400).clamp(0, position.maxScrollExtent),
          );
          await tester.pump();
        }
        expect(position.extentAfter, 0);
      }

      void jumpToTop() => tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .jumpTo(0);

      containerOf(tester).read(appRouterProvider).go(AppRoutes.project(1));
      await tester.pumpAndSettle();
      await jumpToEnd();
      expect(tester.takeException(), isNull);

      // The sort chip is above the rows, beside Show done in a row that
      // scrolls sideways.
      jumpToTop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();
      await scrollToEnd(tester, find.byType(ListView).last);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(l10n.sortTitleAsc));
      await tester.pumpAndSettle();

      jumpToTop();
      await tester.pumpAndSettle();
      final filtered = find.widgetWithText(Tab, 'Filtered');
      await tester.ensureVisible(filtered);
      await tester.pumpAndSettle();
      await tester.tap(filtered);
      await tester.pumpAndSettle();
      await jumpToEnd();
      expect(tester.takeException(), isNull);
    });

    testWidgets('overview sync failure states at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final data = richData();
      final l10n = lookupAppLocalizations(locale);
      await pumpSignedInApp(tester, sync: data);

      data.engine.onRefresh = () async => throw const ServerFailure(502);
      await pullToRefresh(tester, find.byType(CustomScrollView));
      expect(find.byType(DataFailureCard), findsOneWidget);
      await scrollToEnd(tester, find.byType(CustomScrollView));

      // Back to the top, where the notice sits, without a gesture: a drag
      // down would pull to refresh.
      tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      data.engine.onRefresh = () async =>
          throw const NetworkFailure(NetworkProblem.unreachable);
      await pullToRefresh(tester, find.byType(CustomScrollView));
      expect(
        find.textContaining(l10n.offlineNotice, findRichText: true),
        findsOneWidget,
      );
      await scrollToEnd(tester, find.byType(CustomScrollView));
      expect(tester.takeException(), isNull);
    });

    testWidgets('first sync running and failed at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final data = richData(status: const SyncNeverRun());
      final run = Completer<void>();
      data.engine.onEnsureInitialSync = () => run.future;
      await pumpSignedInApp(tester, sync: data, settle: false);
      await pumpUntil(tester, find.byType(FirstSyncScreen));

      // Determinate, so the screen settles.
      data.engine.emit(
        const SyncRunning(
          phase: SyncPhase.archivedTasks,
          done: 1234,
          total: 56789,
          initial: true,
        ),
      );
      await tester.pumpAndSettle();
      await scrollToEnd(tester, find.byType(SingleChildScrollView));
      expect(tester.takeException(), isNull);

      run.completeError(const NetworkFailure(NetworkProblem.tls));
      await tester.pumpAndSettle();
      expect(find.byType(DataFailureCard), findsOneWidget);
      await scrollToEnd(tester, find.byType(SingleChildScrollView));
      expect(tester.takeException(), isNull);
    });

    testWidgets('account tab with a failed sync at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final now = DateTime.now();
      final data = SyncFakes(
        now: now,
        status: SyncFailed(
          failure: const NetworkFailure(NetworkProblem.timeout),
          lastSyncedAt: now.subtract(const Duration(days: 3)),
        ),
      );
      data.engine.onRefresh = () async =>
          throw const NetworkFailure(NetworkProblem.timeout);
      final l10n = lookupAppLocalizations(locale);
      await pumpSignedInApp(tester, sync: data);
      await openTab(tester, l10n.tabAccount);

      // The list builds lazily: the sync section is gone from the tree once
      // the sections below it fill the screen.
      await tester.scrollUntilVisible(
        find.text(l10n.accountSyncFailed),
        100,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text(l10n.accountSyncFailed), findsOneWidget);
      await scrollToEnd(tester, find.byType(ListView));
      expect(tester.takeException(), isNull);
    });

    Finder settingsList() => find.descendant(
      of: find.byType(AccountSettingsPage),
      matching: find.byType(ListView),
    );

    Future<void> openSettingsRow(WidgetTester tester, String title) async {
      final row = find.widgetWithText(ListTile, title);
      tester
          .state<ScrollableState>(
            find.descendant(
              of: settingsList(),
              matching: find.byType(Scrollable),
            ),
          )
          .position
          .jumpTo(0);
      await tester.pump();
      for (var i = 0; i < 80 && row.evaluate().isEmpty; i++) {
        await tester.drag(settingsList(), const Offset(0, -200));
        await tester.pump();
      }
      await Scrollable.ensureVisible(tester.element(row.first), alignment: 0.3);
      await tester.pumpAndSettle();
      await tester.tap(row.first);
      await tester.pumpAndSettle();
    }

    testWidgets('account settings with every section, its sheets, the time '
        'picker and a refused value at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      final data = richData();
      data.projects.savedFilters = const [
        SavedFilterRef(
          projectId: -2,
          title: 'A saved filter with a title long enough to wrap',
        ),
      ];
      data.shared.accountSettings.state = fakeAccountSettingsState(
        settings: const UserSettings(
          name: 'Maximiliane Musterfrau-Beispielhausen',
          defaultProjectId: 1,
          timezone: 'America/Argentina/ComodRivadavia',
          language: 'de-swiss',
          dateDisplay: DateDisplay.weekdayDayMonthYear,
          timeFormat: TimeFormat.twelveHour,
          filterIdUsedOnOverview: -2,
        ),
        pendingEmail: 'maximiliane.musterfrau-beispielhausen@example.org',
      );
      await pumpSignedInApp(tester, sync: data);
      unawaited(
        containerOf(tester)
            .read(appRouterProvider)
            .push(AppRoutes.accountSettings),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AccountSettingsPage), findsOneWidget);
      await scrollToEnd(tester, settingsList());
      expect(tester.takeException(), isNull);

      await openSettingsRow(tester, l10n.accountSettingsDateDisplay);
      await scrollToEnd(tester, find.byType(BottomSheet));
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await openSettingsRow(tester, l10n.accountSettingsLanguage);
      await scrollToEnd(tester, find.byType(BottomSheet));
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await openSettingsRow(tester, l10n.accountSettingsOverdueTime);
      expect(find.byType(TimePickerDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(l10n.cancel).last);
      await tester.pumpAndSettle();

      data.shared.accountSettings.failures['update'] = const DomainError(
        400,
        code: 1025,
      );
      await openSettingsRow(tester, l10n.accountSettingsTimezone);
      // Which zones are suggested depends on where the tests run.
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.data == l10n.accountSettingsTimezoneDevice ||
                  widget.data == l10n.accountSettingsTimezoneSameAsDevice),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.enterText(
        find.widgetWithText(TextField, l10n.accountSettingsTimezoneSearch),
        'Kolkata',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asia/Kolkata'));
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.accountSettingsTimezoneInvalid('Asia/Kolkata')),
        findsOneWidget,
      );
      await scrollToEnd(tester, settingsList());
      expect(tester.takeException(), isNull);
    });

    testWidgets('account settings of a sign-in provider account, offline, at '
        '200 % in dark mode (${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      final data = richData(
        status: SyncFailed(
          failure: const NetworkFailure(NetworkProblem.unreachable),
          lastSyncedAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      );
      data.engine.onRefresh = () async =>
          throw const NetworkFailure(NetworkProblem.unreachable);
      data.shared.accountSettings.failures['refresh'] = const NetworkFailure(
        NetworkProblem.unreachable,
      );
      data.shared.accountSettings.state = fakeAccountSettingsState(
        isLocalUser: false,
        authProvider: 'A sign-in provider with a long name',
      );
      await pumpSignedInApp(tester, sync: data);
      unawaited(
        containerOf(tester)
            .read(appRouterProvider)
            .push(AppRoutes.accountSettings),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.accountSettingsOffline), findsOneWidget);
      await scrollToEnd(tester, settingsList());
      expect(tester.takeException(), isNull);
    });

    testWidgets('avatar page, the photo sheet and the crop page with a '
        'refused upload at 200 % in dark mode (${locale.languageCode})', (
      tester,
    ) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      final data = richData();
      data.shared.accountSettings.failures['uploadAvatar'] = const DomainError(
        400,
        code: 4032,
      );
      final picker = FakeAttachmentPicker()
        ..photos = [const PickedFile(path: '/picked/a.png', name: 'a.png')];
      final files = FakeAvatarFiles();
      await pumpSignedInApp(
        tester,
        sync: data,
        overrides: [picker.providerOverride, files.providerOverride],
      );
      unawaited(
        containerOf(tester)
            .read(appRouterProvider)
            .push(AppRoutes.accountAvatar),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AvatarPage), findsOneWidget);
      await scrollToEnd(
        tester,
        find.descendant(
          of: find.byType(AvatarPage),
          matching: find.byType(ListView),
        ),
      );
      expect(tester.takeException(), isNull);

      final upload = find.widgetWithText(ListTile, l10n.avatarProviderUpload);
      await tester.scrollUntilVisible(
        upload,
        -100,
        scrollable: find
            .descendant(
              of: find.byType(AvatarPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await Scrollable.ensureVisible(tester.element(upload), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(upload);
      await tester.pumpAndSettle();
      await scrollToEnd(tester, find.byType(BottomSheet));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(l10n.avatarChoosePhoto));
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      expect(find.byType(AvatarCropPage), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text(l10n.avatarCropUpload));
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      expect(find.text(l10n.avatarImageTooLarge), findsOneWidget);
      await scrollToEnd(tester, find.byType(SingleChildScrollView).last);
      expect(tester.takeException(), isNull);
    });

    Finder dialogAction(String label) =>
        find.descendant(of: find.byType(Dialog), matching: find.text(label));

    Future<void> pushOverShell(WidgetTester tester, String location) async {
      unawaited(containerOf(tester).read(appRouterProvider).push(location));
      await tester.pumpAndSettle();
    }

    Future<void> scrollToTop(WidgetTester tester, Finder scrollView) async {
      tester
          .state<ScrollableState>(
            find
                .descendant(of: scrollView, matching: find.byType(Scrollable))
                .first,
          )
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
    }

    /// Scrolls [page] from the top until [finder] shows, then taps it.
    Future<void> tapInView(
      WidgetTester tester,
      Finder page,
      Finder finder,
    ) async {
      await scrollToTop(tester, page);
      await tester.scrollUntilVisible(
        finder,
        100,
        scrollable: find
            .descendant(of: page, matching: find.byType(Scrollable))
            .first,
      );
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    testWidgets('account settings security, integrations, data and deletion '
        'with the scheduled note and the deletion dialog at 200 % in dark '
        'mode (${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      final data = richData();
      data.accountSecurity
        ..totp = TotpStatus.setupStarted
        ..export = UserDataExport(
          id: 3,
          size: 123456789,
          expires: DateTime.now().add(const Duration(days: 6)),
        );
      data.shared.accountSettings.state = fakeAccountSettingsState(
        deletionScheduledAt: DateTime.now().add(const Duration(days: 3)),
      );
      await pumpSignedInApp(tester, sync: data);
      await pushOverShell(tester, AppRoutes.accountSettings);

      expect(
        find.text(l10n.accountDeletionCancel, skipOffstage: false),
        findsOneWidget,
      );
      await scrollToEnd(tester, settingsList());
      expect(tester.takeException(), isNull);

      data.shared.accountSettings.state = fakeAccountSettingsState();
      await tester.pumpAndSettle();
      await openSettingsRow(tester, l10n.accountSettingsDeleteAccount);
      expect(find.text(l10n.accountDeletionDialogTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(dialogAction(l10n.cancel));
      await tester.pumpAndSettle();
    });

    testWidgets('account tab with a scheduled deletion at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      final data = richData();
      data.shared.accountSettings.state = fakeAccountSettingsState(
        deletionScheduledAt: DateTime.now().add(const Duration(days: 3)),
      );
      await pumpSignedInApp(tester, sync: data);
      await openTab(tester, l10n.tabAccount);

      expect(
        find.text(l10n.accountDeletionCancel, skipOffstage: false),
        findsOneWidget,
      );
      await scrollToEnd(tester, find.byType(ListView));
      expect(tester.takeException(), isNull);
    });

    testWidgets('sessions with a menu, the details, both confirmations and a '
        'partial failure at 200 % in dark mode (${locale.languageCode})', (
      tester,
    ) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      final data = richData();
      final now = DateTime.now();
      data.accountSecurity.sessionList = [
        ...fakeSessions(now),
        UserSession(
          id: 'long',
          deviceInfo:
              'AnUnknownClientWithAVeryLongName/12.3.4 (an operating system '
              'with a long description; more details)',
          ipAddress: '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
          created: now.subtract(const Duration(days: 30)),
          lastActive: now.subtract(const Duration(days: 20)),
        ),
      ];
      data.accountSecurity.revokeFailures[fakeScriptSessionId] =
          const NetworkFailure(NetworkProblem.unreachable);
      await pumpSignedInApp(tester, sync: data);
      await pushOverShell(tester, AppRoutes.accountSessions);

      expect(find.byType(SessionsPage), findsOneWidget);
      await scrollToEnd(tester, find.byType(SessionsPage));
      expect(tester.takeException(), isNull);

      await tapInView(
        tester,
        find.byType(SessionsPage),
        find.byTooltip(
          l10n.sessionsOptionsFor(l10n.sessionsBrowserOn('Firefox', 'Linux')),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.ancestor(
          of: find.text(l10n.sessionsEnd),
          matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(dialogAction(l10n.cancel));
      await tester.pumpAndSettle();

      await tapInView(
        tester,
        find.byType(SessionsPage),
        find.textContaining('AnUnknownClient'),
      );
      await scrollToEnd(tester, find.byType(BottomSheet));
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tapInView(
        tester,
        find.byType(SessionsPage),
        find.text(l10n.sessionsEndOthers),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(dialogAction(l10n.sessionsEndOthers));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('API tokens, a token sheet, the form with every group, the '
        'expiry picker and the one-time token at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      final data = richData();
      final now = DateTime.now();
      data.accountSecurity.apiTokenList = [
        fakeApiToken(
          title: 'A token for the home automation with a long title',
          expiresAt: now.add(const Duration(days: 12)),
          permissions: const {
            'projects_views_tasks': ['read_all'],
            'tasks_attachments': ['create', 'delete', 'read_all', 'read_one'],
          },
        ),
        fakeApiToken(
          id: 2,
          title: 'Expired',
          expiresAt: now.subtract(const Duration(days: 40)),
        ),
      ];
      await pumpSignedInApp(tester, sync: data);
      await pushOverShell(tester, AppRoutes.accountApiTokens);

      await scrollToEnd(tester, find.byType(ApiTokensPage));
      expect(tester.takeException(), isNull);
      await tapInView(
        tester,
        find.byType(ApiTokensPage),
        find.textContaining('home automation'),
      );
      await scrollToEnd(tester, find.byType(BottomSheet));
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.widgetWithText(OutlinedButton, l10n.apiTokensDelete),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(dialogAction(l10n.cancel));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(l10n.apiTokensNew));
      await tester.pumpAndSettle();
      expect(find.byType(ApiTokenFormPage), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        'A token for a script with a title long enough to wrap twice',
      );
      await tapInView(
        tester,
        find.byType(ApiTokenFormPage),
        find.text(l10n.apiTokenPresetFullAccess),
      );
      for (final group in ['Labels', 'Tasks', 'Other']) {
        await tapInView(
          tester,
          find.byType(ApiTokenFormPage),
          find.byTooltip(l10n.apiTokenFormShowGroup(group)),
        );
      }
      await scrollToEnd(tester, find.byType(ApiTokenFormPage));
      expect(tester.takeException(), isNull);

      await tapInView(
        tester,
        find.byType(ApiTokenFormPage),
        find.text(l10n.apiTokenFormExpiry),
      );
      await scrollToEnd(tester, find.byType(BottomSheet));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(l10n.apiTokenFormExpiryCustom));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(l10n.cancel).last);
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.apiTokenFormCreate));
      await tester.pumpAndSettle();
      expect(find.byType(OneTimeSecretView), findsOneWidget);
      await scrollToEnd(tester, find.byType(OneTimeSecretView));
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(l10n.oneTimeSecretLeaveTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(l10n.oneTimeSecretStay));
      await tester.pumpAndSettle();
    });

    testWidgets('CalDAV with tokens, a confirmation and a new token at 200 % '
        'in dark mode (${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      final data = richData();
      data.accountSecurity
        ..totp = TotpStatus.enabled
        ..caldavTokenList = [
          for (var id = 1; id <= 3; id++)
            CaldavToken(
              id: id,
              created: DateTime.now().subtract(Duration(days: id)),
            ),
        ];
      data.shared.accountSettings.state = fakeAccountSettingsState(
        settings: const UserSettings(name: 'Maximiliane'),
      );
      await pumpSignedInApp(tester, sync: data);
      await pushOverShell(tester, AppRoutes.accountCaldav);

      expect(find.text(l10n.caldavTokenTotp), findsOneWidget);
      await scrollToEnd(tester, find.byType(CaldavPage));
      expect(tester.takeException(), isNull);
      await tapInView(
        tester,
        find.byType(CaldavPage),
        find.byTooltip(l10n.caldavDeleteToken(3)),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(dialogAction(l10n.cancel));
      await tester.pumpAndSettle();

      await tapInView(
        tester,
        find.byType(CaldavPage),
        find.text(l10n.caldavNewToken),
      );
      expect(find.byType(OneTimeSecretPage), findsOneWidget);
      await scrollToEnd(tester, find.byType(OneTimeSecretPage));
      expect(tester.takeException(), isNull);
    });

    testWidgets('data export ready, and failing, at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      final data = richData();
      data.accountSecurity.export = UserDataExport(
        id: 3,
        size: 123456789,
        expires: DateTime.now().add(const Duration(days: 6)),
      );
      await pumpSignedInApp(tester, sync: data);
      await pushOverShell(tester, AppRoutes.accountDataExport);

      await scrollToEnd(tester, find.byType(DataExportPage));
      expect(tester.takeException(), isNull);

      await scrollToTop(tester, find.byType(DataExportPage));
      data.accountSecurity.failures['dataExport'] = const NetworkFailure(
        NetworkProblem.timeout,
      );
      await tester.fling(
        find.text(l10n.dataExportIntro),
        const Offset(0, 600),
        1000,
      );
      await tester.pumpAndSettle();
      await scrollToEnd(tester, find.byType(DataExportPage));
      expect(tester.takeException(), isNull);
    });

    testWidgets('connect screen with an error at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final connector = FakeServerConnector.failing(
        BehindLoginProxy(Uri.parse('https://a-rather-long-host.example.org')),
      );
      await pumpVikunjaApp(tester, connector: connector);

      final context = tester.element(find.byType(Scaffold).first);
      expect(MediaQuery.textScalerOf(context).scale(10), 20);
      expect(Theme.of(context).brightness, Brightness.dark);

      await tester.enterText(
        find.byType(TextFormField),
        'a-rather-long-host.example.org',
      );
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pumpAndSettle();

      expect(find.byType(ConnectionErrorCard), findsOneWidget);
      await scrollToEnd(tester, find.byType(SingleChildScrollView).first);
      expect(tester.takeException(), isNull);
    });

    testWidgets('connecting state at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final pending = Completer<ServerConnection>();
      await pumpVikunjaApp(
        tester,
        connector: FakeServerConnector((_) => pending.future),
      );

      await tester.enterText(
        find.byType(TextFormField),
        'a-rather-long-host.example.org',
      );
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('http confirmation at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      await pumpVikunjaApp(
        tester,
        connector: FakeServerConnector.succeeding(insecureServer()),
      );

      await tester.enterText(find.byType(TextFormField), '192.168.1.20:3456');
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pumpAndSettle();

      expect(find.byWidgetPredicate((w) => w is AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    final l10n = lookupAppLocalizations(locale);
    for (final (name, connection, primaryAction) in [
      ('full', fullServer270(), l10n.continueToSignIn),
      ('unsupported', legacyServer100(), l10n.useDifferentServer),
    ]) {
      testWidgets('$name overview in landscape at 200 % leaves room to read '
          '(${locale.languageCode})', (tester) async {
        const landscape = Size(800, 360);
        usePhoneSurface(tester, logicalSize: landscape);
        useAccessibilityExtremes(tester);
        useLocale(tester, locale);
        await pumpServerOverview(tester, connection);

        expect(
          tester.getSize(find.byType(ListView)).height,
          greaterThanOrEqualTo(landscape.height * 0.75),
        );

        await scrollToEnd(tester, find.byType(ListView));
        final action = tester.getRect(
          find.widgetWithText(FilledButton, primaryAction),
        );
        expect(action.bottom, lessThanOrEqualTo(landscape.height));
        expect(tester.takeException(), isNull);
      });
    }

    for (final (name, connection) in [
      ('full', fullServer270(demoMode: true)),
      ('insecure', insecureServer()),
      ('unsupported', legacyServer100()),
    ]) {
      testWidgets('$name overview at 200 % in dark mode '
          '(${locale.languageCode})', (tester) async {
        useWorstCase(tester, locale);
        await pumpServerOverview(tester, connection);

        await scrollToEnd(tester, find.byType(ListView));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('overview with a sign-in failure at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final auth = AuthFakes();
      auth.tokenGateway.onExchange = (_) async =>
          throw const RateLimited(retryAfter: Duration(minutes: 3));
      await pumpServerOverview(tester, fullServer270(), auth: auth);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.byType(ConnectionErrorCard), findsOneWidget);
      await scrollToEnd(tester, find.byType(ListView));
      expect(tester.takeException(), isNull);
    });

    testWidgets('home with an ended session and a failed retry at 200 % in '
        'dark mode (${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final auth = AuthFakes();
      await auth.seedAccount(
        fullServer270(root: 'https://a-rather-long-host.example.org/vikunja'),
        tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
        displayName: 'Maximiliane Musterfrau-Beispielhausen',
        needsReauth: true,
      );
      auth.webAuthenticator.handler = (_, _) async =>
          throw const WebAuthenticationFailed(
            WebAuthenticationProblem.noBrowser,
          );
      await pumpVikunjaApp(
        tester,
        auth: auth,
        connector: FakeServerConnector.failing(StateError('offline')),
      );
      await openTab(tester, l10n.tabAccount);

      expect(find.byType(ReauthBanner), findsOneWidget);
      await tester.ensureVisible(find.byType(FilledButton).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton).first);
      await tester.pumpAndSettle();

      expect(find.byType(ConnectionErrorCard), findsOneWidget);
      await scrollToEnd(tester, find.byType(ListView));
      expect(tester.takeException(), isNull);
    });

    testWidgets('sign-out dialog at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final auth = AuthFakes();
      await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
      );
      await pumpVikunjaApp(tester, auth: auth);
      await openTab(tester, l10n.tabAccount);

      await scrollToEnd(tester, find.byType(ListView));
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();

      expect(find.byWidgetPredicate((w) => w is AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    Future<ThreeAccounts> longAccounts() async {
      final accounts = ThreeAccounts();
      await accounts.seed(
        aliceName: 'Maximiliane Musterfrau-Beispielhausen',
        bobName: 'Bartholomäus Langername-Doppelname',
        bobNeedsReauth: true,
      );
      accounts.bobData.tasks.pendingChanges = 12;
      return accounts;
    }

    testWidgets('account switcher at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final accounts = await longAccounts();
      await accounts.pump(tester);

      await openSwitcher(tester);
      await scrollToEnd(tester, switcherSheet);

      expect(find.text(l10n.accountManage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('accounts section and removal at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final accounts = await longAccounts();
      await accounts.pump(tester);
      await openTab(tester, l10n.tabAccount);

      await scrollToEnd(tester, find.byType(ListView));
      expect(find.text(l10n.homeSignOutOfThisAccount), findsOneWidget);
      final menu = find.byTooltip(
        l10n.accountMoreActions('Bartholomäus Langername-Doppelname'),
      );
      await tester.scrollUntilVisible(
        menu,
        -200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.accountRemove));
      await tester.pumpAndSettle();

      expect(find.text(l10n.removeAccountDialogTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('add account with server chips at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final accounts = await longAccounts();
      await seedUser(
        accounts.auth,
        oauthServer230(root: 'https://a-rather-long-host-name.example.org'),
        userId: 11,
        username: 'erin',
        displayName: 'Erin',
      );
      await accounts.pump(tester);
      await openSwitcher(tester);
      await scrollToEnd(tester, switcherSheet);
      await tester.tap(inSheet(find.text(l10n.accountAdd)));
      await tester.pumpAndSettle();

      await scrollToEnd(tester, find.byType(SingleChildScrollView));
      expect(find.text(l10n.addAccountYourServers), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
