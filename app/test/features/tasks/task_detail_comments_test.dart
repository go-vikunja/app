import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/network/client_identity.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/description_editor/application/description_target.dart';
import 'package:vikunja_mobile/features/description_editor/presentation/description_editor_page.dart';
import 'package:vikunja_mobile/features/description_editor/presentation/mention_bar.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comment_composer.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comments_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/reaction_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/editor_bridge_fakes.dart';
import '../../helpers/label_user_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

const _anna = User(id: 9, username: 'anna', name: 'Anna');
const _ben = User(id: 10, username: 'ben', name: 'Ben');
const _me = User(id: 7, username: 'alice', name: 'Alice Example');

ServerConnection _withoutComments() {
  final info = ServerInfo(
    version: ServerVersion.tryParse('v2.7.0'),
    rawVersion: 'v2.7.0',
    auth: const AuthMethods(localEnabled: true),
  );
  const versions = {ApiVersion.v1, ApiVersion.v2};
  return ServerConnection(
    rootUri: Uri.parse('https://tasks.example.org/vikunja'),
    apiVersions: versions,
    info: info,
    capabilities: ServerCapabilities.derive(info: info, apiVersions: versions),
  );
}

void main() {
  final now = DateTime(2026, 10, 12, 12);
  late SyncFakes data;
  late FakeUserRepository users;
  late FakeEditorBridges bridges;
  late AuthFakes auth;

  setUp(() {
    auth = AuthFakes();
    data = SyncFakes(now: now);
    data.projects.all = [
      sampleProject(id: 1, title: 'Work', identifier: 'WORK'),
      sampleProject(id: 3, title: 'Acme', parent: 1, identifier: 'ACME'),
    ];
    data.tasks.all = [sampleTask(id: 4, title: 'Ship the order', projectId: 3)];
    data.details
      ..me = _me
      ..detailsByTask[4] = const TaskDetails(maxPermission: Permission.write);
    users = FakeUserRepository(
      projectUsers: {
        3: [_anna, _ben],
      },
    );
    bridges = FakeEditorBridges();
  });

  Finder sheet() => find.byType(TaskDetailSheet).last;

  Finder inSheet(Finder matching) =>
      find.descendant(of: sheet(), matching: matching);

  Finder field() => inSheet(
    find.descendant(
      of: find.byType(CommentComposer),
      matching: find.byType(TextField),
    ),
  );

  Finder sendButton() => inSheet(
    find.byWidgetPredicate(
      (widget) =>
          widget is IconButton &&
          (widget.tooltip == en.commentSend ||
              widget.tooltip == en.commentSending),
    ),
  );

  bool sendEnabled(WidgetTester tester) =>
      tester.widget<IconButton>(sendButton()).onPressed != null;

  void seedComments(List<TaskComment> comments, {int perPage = 50}) {
    data.details
      ..detailsByTask[4] = TaskDetails(
        commentCount: comments.length,
        maxPermission: Permission.write,
      )
      ..commentsPerPage = perPage
      ..commentsByTask[4] = [...comments];
  }

  Future<void> pumpApp(WidgetTester tester, {Size? size}) async {
    usePhoneSurface(tester, logicalSize: size ?? const Size(400, 2400));
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
        userRepositoryProvider.overrideWithValue(users),
        bridges.override,
      ],
    );
  }

  Future<void> showDetail(
    WidgetTester tester, {
    int taskId = 4,
    int? commentId,
  }) async {
    final context = containerOf(tester)
        .read(appRouterProvider)
        .routerDelegate
        .navigatorKey
        .currentContext!;
    unawaited(
      showTaskDetail(
        context,
        task: data.tasks.find(taskId)!,
        commentId: commentId,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openDetail(WidgetTester tester, {Size? size}) async {
    await pumpApp(tester, size: size);
    await showDetail(tester);
  }

  Future<void> showComments(WidgetTester tester) async {
    await tester.tap(inSheet(find.text(en.taskDetailShowComments)));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.tap(field());
    await tester.pump();
    await tester.enterText(field(), text);
    await tester.pump();
  }

  Future<void> send(WidgetTester tester) async {
    await tester.tap(sendButton());
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester, String author) async {
    final menu = inSheet(find.byTooltip(en.commentOptions(author))).first;
    await tester.ensureVisible(menu);
    await tester.pumpAndSettle();
    await tester.tap(menu);
    await tester.pumpAndSettle();
  }

  String? fieldText(WidgetTester tester) =>
      tester.widget<TextField>(field()).controller?.text;

  Future<void> close(WidgetTester tester) async {
    await tester.tap(inSheet(find.byTooltip(en.taskDetailClose)));
    await tester.pumpAndSettle();
  }

  void goOffline(WidgetTester tester) => data.engine.emit(
    SyncFailed(
      failure: const NetworkFailure(NetworkProblem.unreachable),
      lastSyncedAt: now,
    ),
  );

  Iterable<String> announced(WidgetTester tester) =>
      tester.takeAnnouncements().map((announcement) => announcement.message);

  group('the section and the field', () {
    testWidgets('with no comments the section says so, and the first '
        'comment is written in the field below the list', (tester) async {
      await openDetail(tester);

      expect(inSheet(find.text(en.commentsHeading)), findsOneWidget);
      expect(inSheet(find.text(en.commentsEmpty)), findsOneWidget);
      expect(inSheet(find.text(en.taskDetailShowComments)), findsNothing);
      expect(
        inSheet(find.widgetWithText(TextField, en.commentComposerHint)),
        findsOneWidget,
      );
      // Pinned: below the list, not in it.
      expect(
        find.descendant(of: find.byType(ListView), matching: field()),
        findsNothing,
      );

      await type(tester, 'First & <b>only</b>');
      await send(tester);

      expect(data.details.calls, contains('addComment 4'));
      expect(data.details.sentHtml, [
        '<p>First &amp; &lt;b&gt;only&lt;/b&gt;</p>',
      ]);
      expect(inSheet(find.text('First & <b>only</b>')), findsOneWidget);
      expect(inSheet(find.text(en.taskDetailComments(1))), findsOneWidget);
      expect(inSheet(find.text(en.commentsEmpty)), findsNothing);
      expect(fieldText(tester), isEmpty);
      expect(
        tester.takeAnnouncements().map((a) => a.message),
        contains(en.commentPosted),
      );
    });

    testWidgets('Send stays off for blank text and while sending', (
      tester,
    ) async {
      final hold = Completer<void>();
      data.details.beforeCall = (call) async {
        if (call.startsWith('addComment')) await hold.future;
      };
      await openDetail(tester);

      expect(sendEnabled(tester), isFalse);
      await type(tester, '  \n ');
      expect(sendEnabled(tester), isFalse);
      await type(tester, 'Ready');
      expect(sendEnabled(tester), isTrue);

      await tester.tap(sendButton());
      await tester.pump();
      expect(sendEnabled(tester), isFalse);
      expect(inSheet(find.byTooltip(en.commentSending)), findsOneWidget);
      await tester.tap(sendButton(), warnIfMissed: false);
      hold.complete();
      await tester.pumpAndSettle();

      expect(data.details.sentHtml, ['<p>Ready</p>']);
    });

    testWidgets('offline Send is off and says why; the text stays', (
      tester,
    ) async {
      await openDetail(tester);
      data.engine.emit(
        SyncFailed(
          failure: const NetworkFailure(NetworkProblem.unreachable),
          lastSyncedAt: now,
        ),
      );
      await tester.pumpAndSettle();

      await type(tester, 'Later');
      expect(sendEnabled(tester), isFalse);
      expect(inSheet(find.text(en.commentComposerOffline)), findsOneWidget);
      expect(fieldText(tester), 'Later');
    });

    testWidgets('a failed send keeps the text and says why', (tester) async {
      data.details.addCommentFailure = const Forbidden();
      await openDetail(tester);

      await type(tester, 'Kept');
      await send(tester);

      expect(inSheet(find.text(en.commentsReadOnlyNote)), findsOneWidget);
      expect(fieldText(tester), 'Kept');
      expect(sendEnabled(tester), isTrue);
    });

    testWidgets('what was typed stays as a draft of the task and comes back '
        'with the sheet', (tester) async {
      await openDetail(tester);
      await type(tester, 'Half a thought');
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(inSheet(find.byTooltip(en.taskDetailClose)));
      await tester.pumpAndSettle();
      await showDetail(tester);

      expect(fieldText(tester), 'Half a thought');

      await send(tester);
      await tester.tap(inSheet(find.byTooltip(en.taskDetailClose)));
      await tester.pumpAndSettle();
      await showDetail(tester);
      expect(fieldText(tester), isEmpty);
    });

    for (final (name, kept) in const [
      ('once kept as a draft', true),
      ('sent right after typing', false),
    ]) {
      testWidgets('a comment the sheet closes on while it is sent, $name, '
          'does not come back as a draft', (tester) async {
        final hold = Completer<void>();
        data.details.beforeCall = (call) async {
          if (call.startsWith('addComment')) await hold.future;
        };
        await openDetail(tester);
        await type(tester, 'Looks good');
        if (kept) await tester.pump(const Duration(seconds: 1));

        await tester.tap(sendButton());
        await tester.pump();
        await close(tester);
        hold.complete();
        await tester.pumpAndSettle();

        expect(find.text(en.commentPosted), findsOneWidget);
        await showDetail(tester);
        expect(fieldText(tester), isEmpty);
        expect(data.details.sentHtml, ['<p>Looks good</p>']);
      });
    }

    testWidgets('a send that fails after the sheet closed says so below it '
        'and keeps the text', (tester) async {
      final hold = Completer<void>();
      data.details
        ..beforeCall = (call) async {
          if (call.startsWith('addComment')) await hold.future;
        }
        ..addCommentFailure = const NetworkFailure(NetworkProblem.unreachable);
      await openDetail(tester);
      await type(tester, 'Not yet');

      await tester.tap(sendButton());
      await tester.pump();
      await close(tester);
      hold.complete();
      await tester.pumpAndSettle();

      expect(find.text(en.commentFailedNeedsConnection), findsOneWidget);
      data.details.addCommentFailure = null;
      await showDetail(tester);
      expect(fieldText(tester), 'Not yet');
    });

    testWidgets("@ suggests the project's people and sends the web's "
        'mention node', (tester) async {
      await openDetail(tester);

      await type(tester, 'Thanks @an');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(users.searches, contains((3, 'an')));
      expect(inSheet(find.byType(MentionBar)), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: inSheet(find.byType(MentionBar)),
          matching: find.text('Anna'),
        ),
      );
      await tester.pumpAndSettle();
      expect(inSheet(find.byType(MentionBar)), findsNothing);
      expect(fieldText(tester), 'Thanks @Anna ');

      final controller = tester.widget<TextField>(field()).controller!;
      controller.value = TextEditingValue(
        text: '${controller.text}for it',
        selection: const TextSelection.collapsed(offset: 19),
      );
      await tester.pump();
      await send(tester);

      const mention =
          '<mention-user data-id="anna" data-label="Anna" '
          'data-mention-suggestion-char="@"></mention-user>';
      expect(data.details.sentHtml, ['<p>Thanks $mention for it</p>']);
    });

    testWidgets('on a server without comments there is neither section nor '
        'field', (tester) async {
      usePhoneSurface(tester, logicalSize: const Size(400, 2400));
      final auth = AuthFakes();
      await auth.seedAccount(
        _withoutComments(),
        tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
      );
      await pumpVikunjaApp(tester, auth: auth, sync: data);
      await showDetail(tester);

      expect(inSheet(find.text(en.commentsHeading)), findsNothing);
      expect(find.byType(CommentComposer), findsNothing);
    });
  });

  group('who may write', () {
    testWidgets('a user who may only read sees the comments and reactions '
        'but cannot change them', (tester) async {
      seedComments([
        sampleComment(
          id: 1,
          reactions: const {
            '👍': [_anna],
          },
        ),
      ]);
      data.details.detailsByTask[4] = const TaskDetails(
        commentCount: 1,
        maxPermission: Permission.read,
        reactions: {
          '🎉': [_anna],
        },
      );
      await openDetail(tester);
      await showComments(tester);

      expect(find.byType(CommentComposer), findsNothing);
      expect(inSheet(find.text(en.commentsReadOnlyNote)), findsOneWidget);
      expect(inSheet(find.byTooltip(en.reactionAdd)), findsNothing);
      await tester.tap(inSheet(find.text('🎉 1')));
      await tester.tap(inSheet(find.text('👍 1')));
      await tester.pumpAndSettle();
      expect(data.details.calls.where((c) => c.contains('Reaction')), isEmpty);

      // Copying the link is all that is left.
      await openMenu(tester, 'Anna');
      expect(find.text(en.commentCopyLink), findsOneWidget);
      expect(find.text(en.commentReply), findsNothing);
    });

    testWidgets('a user who may only read never gets a field to type in, '
        'not even while the details load', (tester) async {
      final hold = Completer<void>();
      data.details
        ..detailsByTask[4] = const TaskDetails(maxPermission: Permission.read)
        ..beforeCall = (call) async {
          if (call.startsWith('details')) await hold.future;
        };
      await openDetail(tester);

      expect(tester.widget<TextField>(field()).enabled, isFalse);
      expect(sendEnabled(tester), isFalse);

      hold.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CommentComposer), findsNothing);
      expect(inSheet(find.text(en.commentsReadOnlyNote)), findsOneWidget);
    });

    testWidgets('offline the field shows where an earlier read said the task '
        'may be written', (tester) async {
      data.tasks.all = [
        ...data.tasks.all,
        sampleTask(id: 5, title: 'Never opened', projectId: 3),
      ];
      await openDetail(tester);
      await close(tester);
      goOffline(tester);
      data.details.detailsFailure = const NetworkFailure(
        NetworkProblem.unreachable,
      );
      await tester.pumpAndSettle();

      await showDetail(tester);
      expect(field(), findsOneWidget);
      expect(tester.widget<TextField>(field()).enabled, isTrue);
      expect(sendEnabled(tester), isFalse);
      await close(tester);

      await showDetail(tester, taskId: 5);
      expect(find.byType(CommentComposer), findsNothing);
    });

    testWidgets('offline, reactions, Edit and Delete are off', (tester) async {
      seedComments([
        sampleComment(
          id: 1,
          author: _me,
          html: '<p>Mine</p>',
          reactions: const {
            '👀': [_anna],
          },
        ),
      ]);
      data.details.detailsByTask[4] = const TaskDetails(
        commentCount: 1,
        maxPermission: Permission.write,
        reactions: {
          '👍': [_anna],
        },
      );
      await openDetail(tester);
      await showComments(tester);
      goOffline(tester);
      await tester.pumpAndSettle();

      await tester.tap(inSheet(find.text('👍 1')));
      await tester.tap(inSheet(find.text('👀 1')));
      await tester.pumpAndSettle();
      expect(inSheet(find.text('👍 1')), findsOneWidget);
      await tester.tap(inSheet(find.byTooltip(en.reactionAdd)).first);
      await tester.pumpAndSettle();
      expect(find.text(en.reactionOther), findsNothing);

      await openMenu(tester, 'Alice Example');
      for (final action in [en.commentEdit, en.commentDelete]) {
        final item = tester.widget<PopupMenuItem<Object?>>(
          find.ancestor(
            of: find.text(action),
            matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
          ),
        );
        expect(item.enabled, isFalse, reason: action);
      }
      await tester.tap(find.text(en.commentDelete), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text(en.commentDeleteTitle), findsNothing);
      expect(
        data.details.calls.where(
          (call) => call.contains('Reaction') || call.contains('delete'),
        ),
        isEmpty,
      );
    });

    testWidgets('in an archived project there is a note instead of the '
        'field', (tester) async {
      data.projects.all = [
        sampleProject(id: 1, title: 'Work', identifier: 'WORK'),
        copyProject(
          sampleProject(id: 3, title: 'Acme', parent: 1),
          isArchived: true,
        ),
      ];
      await openDetail(tester);

      expect(find.byType(CommentComposer), findsNothing);
      expect(inSheet(find.text(en.commentsArchivedNote)), findsOneWidget);
    });
  });

  group('each comment', () {
    testWidgets("the menu: Reply and Copy link for anyone's, Edit and "
        'Delete for the own ones too', (tester) async {
      seedComments([
        sampleComment(id: 1),
        sampleComment(id: 2, author: _me, html: '<p>Mine</p>'),
      ]);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await openDetail(tester);
      await showComments(tester);

      await openMenu(tester, 'Anna');
      expect(find.text(en.commentReply), findsOneWidget);
      expect(find.text(en.commentEdit), findsNothing);
      expect(find.text(en.commentDelete), findsNothing);
      await tester.tap(find.text(en.commentCopyLink));
      await tester.pumpAndSettle();
      expect(copied, 'https://tasks.example.org/vikunja/tasks/4#comment-1');
      expect(inSheet(find.text(en.commentLinkCopied)), findsOneWidget);

      await openMenu(tester, 'Alice Example');
      expect(find.text(en.commentEdit), findsOneWidget);
      expect(find.text(en.commentDelete), findsOneWidget);
    });

    testWidgets("all of a comment's menu button takes taps", (tester) async {
      seedComments([sampleComment(id: 1)]);
      await openDetail(tester);
      await showComments(tester);
      final menu = find.descendant(
        of: inSheet(find.byType(CommentTile)),
        matching: find.byWidgetPredicate((widget) => widget is PopupMenuButton),
      );
      await tester.ensureVisible(menu);
      await tester.pumpAndSettle();

      final target = tester.getRect(menu);
      expect(target.height, greaterThanOrEqualTo(48));
      await tester.tapAt(target.topCenter + const Offset(0, 4));
      await tester.pumpAndSettle();

      expect(find.text(en.commentReply), findsOneWidget);
    });

    testWidgets('a link that cannot be copied says so', (tester) async {
      seedComments([sampleComment(id: 1)]);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            throw PlatformException(code: 'clipboard');
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await openDetail(tester);
      await showComments(tester);

      await openMenu(tester, 'Anna');
      await tester.tap(find.text(en.commentCopyLink));
      await tester.pumpAndSettle();

      expect(inSheet(find.text(en.copyToClipboardFailed)), findsOneWidget);
      expect(inSheet(find.text(en.commentLinkCopied)), findsNothing);
    });

    testWidgets('where the system confirms a copy, the app only tells the '
        'screen reader', (tester) async {
      seedComments([sampleComment(id: 1)]);
      auth.preferences.values[androidVersionKey] = '14';
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await openDetail(tester);
      await showComments(tester);
      tester.takeAnnouncements();

      await openMenu(tester, 'Anna');
      await tester.tap(find.text(en.commentCopyLink));
      await tester.pumpAndSettle();

      expect(inSheet(find.text(en.commentLinkCopied)), findsNothing);
      expect(announced(tester), contains(en.commentLinkCopied));
    });

    testWidgets('a screen reader hears a reply set up and dropped', (
      tester,
    ) async {
      seedComments([sampleComment(id: 1)]);
      await openDetail(tester);
      await showComments(tester);
      tester.takeAnnouncements();

      await openMenu(tester, 'Anna');
      await tester.tap(find.text(en.commentReply));
      await tester.pumpAndSettle();
      expect(announced(tester), contains(en.commentReplyingTo('Anna')));

      await tester.tap(inSheet(find.byTooltip(en.commentReplyCancel)));
      await tester.pumpAndSettle();
      expect(announced(tester), contains(en.commentReplyDropped));
    });

    testWidgets("Reply quotes the comment the web's way, without its "
        'mentions', (tester) async {
      const quoted =
          '<p>Ask <mention-user data-id="ben" data-label="Ben" '
          'data-mention-suggestion-char="@"></mention-user></p>';
      seedComments([sampleComment(id: 1, html: quoted)]);
      await openDetail(tester);
      await showComments(tester);

      await openMenu(tester, 'Anna');
      await tester.tap(find.text(en.commentReply));
      await tester.pumpAndSettle();
      expect(inSheet(find.text(en.commentReplyingTo('Anna'))), findsOneWidget);
      expect(inSheet(find.text('Ask @Ben')), findsWidgets);

      await type(tester, 'Done');
      await send(tester);

      expect(data.details.sentHtml, [
        commentHtmlFromText(
          'Done',
          reply: const QuotedComment(id: 1, html: quoted),
        ),
      ]);
      expect(
        data.details.sentHtml.single,
        startsWith(
          '<blockquote data-comment-id="1"><p>Ask @Ben</p></blockquote>',
        ),
      );
      expect(inSheet(find.text(en.commentReplyingTo('Anna'))), findsNothing);
    });

    testWidgets('a reply can be dropped before sending', (tester) async {
      seedComments([sampleComment(id: 1)]);
      await openDetail(tester);
      await showComments(tester);
      await openMenu(tester, 'Anna');
      await tester.tap(find.text(en.commentReply));
      await tester.pumpAndSettle();

      await tester.tap(inSheet(find.byTooltip(en.commentReplyCancel)));
      await tester.pumpAndSettle();
      await type(tester, 'Plain');
      await send(tester);

      expect(data.details.sentHtml, ['<p>Plain</p>']);
    });

    testWidgets('Edit opens the editor with the comment and shows what it '
        'saved', (tester) async {
      seedComments([sampleComment(id: 2, author: _me, html: '<p>Mine</p>')]);
      await openDetail(tester);
      await showComments(tester);

      await openMenu(tester, 'Alice Example');
      await tester.tap(find.text(en.commentEdit));
      await tester.pumpAndSettle();

      final page = tester.widget<DescriptionEditorPage>(
        find.byType(DescriptionEditorPage),
      );
      final target = page.target as CommentTarget;
      expect(target.taskId, 4);
      expect(target.projectId, 3);
      expect(target.comment.id, 2);
      expect(bridges.last.init!.html, '<p>Mine</p>');
      expect(find.text(en.commentEditorTitle), findsOneWidget);

      bridges.last.edit('<p>Mine, <strong>better</strong></p>');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, en.taskEditSave));
      await tester.pumpAndSettle();

      expect(data.details.calls, contains('editComment 4 2'));
      expect(find.byType(DescriptionEditorPage), findsNothing);
      expect(
        inSheet(find.textContaining('Mine, better', findRichText: true)),
        findsOneWidget,
      );
      expect(inSheet(find.text(en.commentSaved)), findsOneWidget);
    });

    testWidgets('back from editing a comment the keyboard stays down, even '
        'when the comment field had the focus', (tester) async {
      seedComments([sampleComment(id: 2, author: _me, html: '<p>Mine</p>')]);
      await openDetail(tester);
      await showComments(tester);
      await tester.tap(field());
      await tester.pump();

      await openMenu(tester, 'Alice Example');
      await tester.tap(find.text(en.commentEdit));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(DescriptionEditorPage), findsNothing);
      expect(
        tester.widget<TextField>(field()).focusNode?.hasFocus,
        isNot(true),
      );
      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('Delete asks first, then removes the comment, and "Load '
        'more" still brings the one that moved up', (tester) async {
      seedComments([
        sampleComment(id: 1, author: _me, html: '<p>One</p>'),
        sampleComment(id: 2, html: '<p>Two</p>'),
        sampleComment(id: 3, html: '<p>Three</p>'),
      ], perPage: 2);
      await openDetail(tester);
      await showComments(tester);
      expect(inSheet(find.text('Three')), findsNothing);

      await openMenu(tester, 'Alice Example');
      await tester.tap(find.text(en.commentDelete));
      await tester.pumpAndSettle();
      expect(find.text(en.commentDeleteTitle), findsOneWidget);
      await tester.tap(find.text(en.cancel));
      await tester.pumpAndSettle();
      expect(data.details.calls, isNot(contains('deleteComment 4 1')));

      await openMenu(tester, 'Alice Example');
      await tester.tap(find.text(en.commentDelete));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text(en.commentDelete),
        ),
      );
      await tester.pumpAndSettle();

      expect(data.details.calls, contains('deleteComment 4 1'));
      expect(inSheet(find.text('One')), findsNothing);
      expect(inSheet(find.text(en.commentDeleted)), findsOneWidget);
      expect(inSheet(find.text(en.taskDetailComments(2))), findsOneWidget);

      data.details.calls.clear();
      await tester.tap(inSheet(find.text(en.taskDetailMoreComments)));
      await tester.pumpAndSettle();
      expect(data.details.calls, [
        'comments 4 page 1 oldest',
        'comments 4 page 2 oldest',
      ]);
      expect(inSheet(find.text('Two')), findsOneWidget);
      expect(inSheet(find.text('Three')), findsOneWidget);
    });

    testWidgets('a deletion the server refuses keeps the comment and says '
        'why', (tester) async {
      seedComments([sampleComment(id: 1, author: _me, html: '<p>One</p>')]);
      data.details.deleteCommentFailure = const DomainError(412, code: 3008);
      await openDetail(tester);
      await showComments(tester);

      await openMenu(tester, 'Alice Example');
      await tester.tap(find.text(en.commentDelete));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text(en.commentDelete),
        ),
      );
      await tester.pumpAndSettle();

      expect(inSheet(find.text('One')), findsOneWidget);
      expect(inSheet(find.text(en.commentsArchivedNote)), findsOneWidget);
    });
  });

  group('reactions', () {
    testWidgets('a tap toggles the own reaction on the task at once and on '
        'the server', (tester) async {
      data.details.detailsByTask[4] = const TaskDetails(
        maxPermission: Permission.write,
        reactions: {
          '👍': [_anna],
        },
      );
      await openDetail(tester);

      await tester.tap(inSheet(find.text('👍 1')));
      await tester.pumpAndSettle();
      expect(inSheet(find.text('👍 2')), findsOneWidget);
      expect(data.details.calls.last, 'addReaction task 4 👍');

      await tester.tap(inSheet(find.text('👍 2')));
      await tester.pumpAndSettle();
      expect(inSheet(find.text('👍 1')), findsOneWidget);
      expect(data.details.calls.last, 'removeReaction task 4 👍');
    });

    testWidgets('a failed toggle is undone and says why', (tester) async {
      data.details
        ..detailsByTask[4] = const TaskDetails(
          maxPermission: Permission.write,
          reactions: {
            '👍': [_anna],
          },
        )
        ..reactionFailure = const NetworkFailure(NetworkProblem.unreachable);
      await openDetail(tester);

      await tester.tap(inSheet(find.text('👍 1')));
      await tester.pumpAndSettle();

      expect(inSheet(find.text('👍 1')), findsOneWidget);
      expect(
        inSheet(find.text(en.commentFailedNeedsConnection)),
        findsOneWidget,
      );
    });

    testWidgets("a toggle leaves the user's other reactions alone, and a "
        'failed removal puts the user back in place', (tester) async {
      data.details.detailsByTask[4] = const TaskDetails(
        maxPermission: Permission.write,
        reactions: {
          '🎉': [_me, _anna],
          '👍': [_anna],
        },
      );
      await openDetail(tester);

      await tester.tap(inSheet(find.text('👍 1')));
      await tester.pumpAndSettle();
      expect(inSheet(find.text('🎉 2')), findsOneWidget);
      expect(inSheet(find.text('👍 2')), findsOneWidget);

      data.details.reactionFailure = const NetworkFailure(
        NetworkProblem.unreachable,
      );
      await tester.tap(inSheet(find.text('🎉 2')));
      await tester.pumpAndSettle();
      await tester.longPress(inSheet(find.text('🎉 2')));
      await tester.pumpAndSettle();
      expect(
        find.text(en.reactionBySeveral('Alice Example', 'Anna', '🎉')),
        findsOne,
      );
    });

    testWidgets('a long press shows who reacted', (tester) async {
      data.details.detailsByTask[4] = const TaskDetails(
        maxPermission: Permission.write,
        reactions: {
          '👍': [_anna, _ben],
        },
      );
      await openDetail(tester);

      await tester.longPress(inSheet(find.text('👍 2')));
      await tester.pumpAndSettle();

      expect(find.text(en.reactionBySeveral('Anna', 'Ben', '👍')), findsOne);
      expect(data.details.calls.where((c) => c.contains('Reaction')), isEmpty);
    });

    testWidgets('Add reaction offers a quick set and any other emoji', (
      tester,
    ) async {
      await openDetail(tester);

      await tester.tap(inSheet(find.byTooltip(en.reactionAdd)));
      await tester.pumpAndSettle();
      for (final reaction in quickReactions) {
        expect(find.text(reaction), findsOneWidget);
      }
      await tester.tap(find.text('🎉'));
      await tester.pumpAndSettle();
      expect(data.details.calls.last, 'addReaction task 4 🎉');
      expect(inSheet(find.text('🎉 1')), findsOneWidget);

      await tester.tap(inSheet(find.byTooltip(en.reactionAdd)));
      await tester.pumpAndSettle();
      final other = find.widgetWithText(TextField, en.reactionOther);
      await tester.enterText(other, '🦙' * 21);
      await tester.pump();
      await tester.tap(find.byTooltip(en.reactionOtherAdd));
      await tester.pumpAndSettle();
      expect(find.text(en.reactionTooLong), findsOneWidget);

      await tester.enterText(other, ' 🦙 ');
      await tester.pump();
      await tester.tap(find.byTooltip(en.reactionOtherAdd));
      await tester.pumpAndSettle();
      expect(data.details.calls.last, 'addReaction task 4 🦙');
      expect(inSheet(find.text('🦙 1')), findsOneWidget);
    });

    testWidgets('on a comment too', (tester) async {
      seedComments([
        sampleComment(
          id: 1,
          reactions: const {
            '👀': [_anna],
          },
        ),
      ]);
      await openDetail(tester);
      await showComments(tester);

      await tester.tap(inSheet(find.text('👀 1')));
      await tester.pumpAndSettle();
      expect(data.details.calls.last, 'addReaction comment 1 👀');
      expect(inSheet(find.text('👀 2')), findsOneWidget);

      final addOnComment = find.descendant(
        of: inSheet(find.byType(CommentTile)),
        matching: find.byTooltip(en.reactionAdd),
      );
      await tester.tap(addOnComment);
      await tester.pumpAndSettle();
      await tester.tap(find.text('🚀'));
      await tester.pumpAndSettle();
      expect(data.details.calls.last, 'addReaction comment 1 🚀');
    });
  });

  group('a live thread', () {
    testWidgets('a change on the server reads the details and the shown '
        'comments again', (tester) async {
      seedComments([sampleComment(id: 1, html: '<p>Hello</p>')]);
      await openDetail(tester);
      await showComments(tester);
      data.details.calls.clear();

      data.details.commentsByTask[4]!.add(
        sampleComment(id: 2, author: _ben, html: '<p>New from Ben</p>'),
      );
      data.details.detailsByTask[4] = const TaskDetails(
        commentCount: 2,
        maxPermission: Permission.write,
      );
      data.details.serverChanged(4, DateTime.utc(2026, 10, 12, 13));
      await tester.pumpAndSettle();

      expect(
        data.details.calls,
        containsAll(['details 4', 'comments 4 page 1 oldest']),
      );
      expect(inSheet(find.text('New from Ben')), findsOneWidget);
      expect(inSheet(find.text(en.taskDetailComments(2))), findsOneWidget);
    });

    testWidgets('a comment by someone else arriving while open is marked '
        'read', (tester) async {
      await openDetail(tester);
      expect(data.details.markedRead, isEmpty);

      data.details.detailsByTask[4] = const TaskDetails(
        commentCount: 1,
        isUnread: true,
        maxPermission: Permission.write,
      );
      data.details.serverChanged(4, DateTime.utc(2026, 10, 12, 13));
      await tester.pumpAndSettle();

      expect(data.details.markedRead, [4]);
    });
  });

  group('opened at a comment', () {
    List<TaskComment> many(int count) => [
      for (var id = 1; id <= count; id++)
        sampleComment(id: id, html: '<p>Comment number $id</p>'),
    ];

    testWidgets('scrolls to it and tints it for a moment', (tester) async {
      seedComments(many(30));
      await pumpApp(tester, size: const Size(400, 800));
      await showDetail(tester, commentId: 30);

      final row = inSheet(find.text('Comment number 30'));
      expect(row, findsOneWidget);
      final viewport = tester.getRect(
        find.descendant(of: sheet(), matching: find.byType(ListView)),
      );
      expect(viewport.contains(tester.getCenter(row)), isTrue);
      final tile = tester.widget<CommentTile>(
        find.ancestor(of: row, matching: find.byType(CommentTile)),
      );
      expect(tile.highlighted, isTrue);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CommentTile>(
              find.ancestor(of: row, matching: find.byType(CommentTile)),
            )
            .highlighted,
        isFalse,
      );
    });

    testWidgets('one not on the first page shows the comments', (tester) async {
      seedComments(many(30), perPage: 5);
      await pumpApp(tester, size: const Size(400, 800));
      await showDetail(tester, commentId: 30);

      expect(data.details.calls, contains('comments 4 page 1 oldest'));
      final heading = inSheet(find.text(en.taskDetailComments(30)));
      final viewport = tester.getRect(
        find.descendant(of: sheet(), matching: find.byType(ListView)),
      );
      expect(viewport.contains(tester.getCenter(heading)), isTrue);
    });
  });
}
