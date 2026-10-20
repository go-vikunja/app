import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/description_editor/application/description_drafts.dart';
import 'package:vikunja_mobile/features/description_editor/application/editor_protocol.dart';
import 'package:vikunja_mobile/features/description_editor/presentation/description_editor_page.dart';
import 'package:vikunja_mobile/features/description_editor/presentation/editor_theme.dart';
import 'package:vikunja_mobile/features/description_editor/presentation/editor_toolbar.dart';
import 'package:vikunja_mobile/features/description_editor/presentation/mention_bar.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/editor_bridge_fakes.dart';
import '../../helpers/label_user_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  const jane = User(id: 7, username: 'jdoe', name: 'Jane Doe');
  const john = User(id: 8, username: 'john');
  late SyncFakes data;
  late FakeEditorBridges bridges;
  late FakeUserRepository users;
  late AuthFakes auth;

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [
      copyProject(
        sampleProject(id: 1, title: 'Work', identifier: 'WORK'),
        description: '<p>About work</p>',
      ),
    ];
    data.tasks.all = [
      sampleTask(
        id: 1,
        title: 'Quarterly report',
        description: '<p>Numbers</p>',
      ),
      sampleTask(id: 2, title: 'Bare task'),
    ];
    bridges = FakeEditorBridges();
    auth = AuthFakes();
    users = FakeUserRepository(
      projectUsers: {
        1: [jane, john],
      },
      known: [jane],
    );
  });

  /// Opens the editor for [route]; what it pops with lands in the list.
  Future<List<bool?>> openEditor(
    WidgetTester tester, {
    String? route,
    bool settle = true,
    bool pumpApp = true,
    Size size = phoneSize,
  }) async {
    if (pumpApp) {
      usePhoneSurface(tester, logicalSize: size);
      await pumpSignedInApp(
        tester,
        sync: data,
        auth: auth,
        now: now,
        overrides: [
          bridges.override,
          userRepositoryProvider.overrideWithValue(users),
        ],
      );
    }
    final popped = <bool?>[];
    unawaited(
      containerOf(tester)
          .read(appRouterProvider)
          .push<bool>(route ?? AppRoutes.taskDescription(1))
          .then(popped.add),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await pumpFrames(tester, 3);
    }
    return popped;
  }

  Finder saveButton() => find.widgetWithText(TextButton, en.taskEditSave);

  bool saveEnabled(WidgetTester tester) =>
      tester.widget<TextButton>(saveButton()).onPressed != null;

  Future<void> tapTool(WidgetTester tester, String tooltip) async {
    await tester.ensureVisible(find.byTooltip(tooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(tooltip));
    await tester.pumpAndSettle();
  }

  group('opening', () {
    testWidgets('the editor gets the stored description, the theme, the '
        "account's links and the placeholder, then the focus", (tester) async {
      await openEditor(tester);

      final bridge = bridges.last;
      final init = bridge.init!;
      final context = tester.element(find.byType(DescriptionEditorPage));
      expect(init.html, '<p>Numbers</p>');
      expect(init.placeholder, en.descriptionEditorPlaceholder);
      expect(init.label, en.descriptionEditorTitle);
      expect(init.imageLabel, en.descriptionEditorImage);
      expect(init.locale, 'en');
      expect(init.theme, editorThemeOf(context));
      expect(init.theme.dark, isFalse);
      expect(init.theme.fontScale, 1);
      expect(init.links.taskLinkBases, ['https://tasks.example.org/vikunja']);
      expect(init.links.apiRoot, 'https://tasks.example.org/vikunja');
      expect(bridge.background, Theme.of(context).colorScheme.surface);
      expect(bridge.focusCalls, 1);
      expect(find.byKey(FakeEditorBridge.viewKey), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('at 200 % text in dark mode the page gets both', (
      tester,
    ) async {
      useAccessibilityExtremes(tester);
      await openEditor(tester);

      final theme = bridges.last.init!.theme;
      expect(theme.dark, isTrue);
      expect(theme.fontScale, 2);
      expect(
        theme.colors.keys,
        unorderedEquals([
          'text',
          'background',
          'primary',
          'outline',
          'surface',
          'error',
          'selection',
          'link',
          'codeBackground',
        ]),
      );
      expect(theme.colors['selection'], startsWith('rgba('));
    });

    testWidgets('in German the page gets German texts and its language', (
      tester,
    ) async {
      useLocale(tester, const Locale('de'));
      await openEditor(tester);

      final init = bridges.last.init!;
      final de = lookupAppLocalizations(const Locale('de'));
      expect(init.locale, 'de');
      expect(init.label, de.descriptionEditorTitle);
      expect(init.imageLabel, de.descriptionEditorImage);
    });

    testWidgets('a change of brightness reaches the open page', (tester) async {
      await openEditor(tester);
      expect(bridges.last.themes, isEmpty);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpAndSettle();

      expect(bridges.last.themes.last.dark, isTrue);
    });

    testWidgets('a page that fails to load offers to try again', (
      tester,
    ) async {
      bridges.readyOnStart = false;
      await openEditor(tester, settle: false);
      expect(find.text(en.descriptionEditorLoading), findsOneWidget);

      bridges.last.emit(const EditorFailed('init failed'));
      await tester.pumpAndSettle();
      expect(find.text(en.descriptionEditorFailed), findsOneWidget);

      bridges.readyOnStart = true;
      await tester.tap(find.text(en.retry));
      await tester.pumpAndSettle();

      expect(bridges.created, hasLength(2));
      expect(bridges.created.first.disposed, isTrue);
      expect(bridges.last.init!.html, '<p>Numbers</p>');
      expect(find.text(en.descriptionEditorFailed), findsNothing);
    });

    testWidgets('a page that never gets ready counts as failed', (
      tester,
    ) async {
      bridges.readyOnStart = false;
      await openEditor(tester, settle: false);

      await tester.pump(DescriptionEditorPage.loadTimeout);
      await tester.pump();

      expect(find.text(en.descriptionEditorFailed), findsOneWidget);
    });
  });

  group('toolbar', () {
    testWidgets('every button sends its command', (tester) async {
      await openEditor(tester);
      final bridge = bridges.last;

      for (final (tooltip, command) in [
        (en.editorBold, EditorCommandName.bold),
        (en.editorItalic, EditorCommandName.italic),
        (en.editorUnderline, EditorCommandName.underline),
        (en.editorStrike, EditorCommandName.strike),
        (en.editorCode, EditorCommandName.code),
        (en.editorBulletList, EditorCommandName.bulletList),
        (en.editorOrderedList, EditorCommandName.orderedList),
        (en.editorTaskList, EditorCommandName.taskList),
        (en.editorQuote, EditorCommandName.blockquote),
        (en.editorCodeBlock, EditorCommandName.codeBlock),
        (en.editorDivider, EditorCommandName.horizontalRule),
        (en.editorClearFormatting, EditorCommandName.clearFormatting),
      ]) {
        await tapTool(tester, tooltip);
        expect(bridge.commands.last, EditorCommand(command), reason: tooltip);
      }
      expect(bridge.commands, hasLength(12));
    });

    testWidgets('the text style menu sets paragraphs and headings', (
      tester,
    ) async {
      await openEditor(tester);

      Finder option(String text) =>
          find.widgetWithText(CheckedPopupMenuItem<int>, text);
      await tapTool(tester, en.editorTextStyle);
      await tester.tap(option(en.editorHeading(2)));
      await tester.pumpAndSettle();
      await tapTool(tester, en.editorTextStyle);
      await tester.tap(option(en.editorParagraph));
      await tester.pumpAndSettle();

      expect(bridges.last.commands, [
        EditorCommand.heading(2),
        EditorCommand.heading(0),
      ]);
    });

    testWidgets('the table menu inserts a table outside one and changes it '
        'inside', (tester) async {
      await openEditor(tester);
      final bridge = bridges.last;

      await tapTool(tester, en.editorTable);
      expect(
        tester
            .widget<PopupMenuItem<Object?>>(
              find.ancestor(
                of: find.text(en.editorAddRow),
                matching: find.byWidgetPredicate(
                  (widget) => widget is PopupMenuItem,
                ),
              ),
            )
            .enabled,
        isFalse,
      );
      await tester.tap(find.text(en.editorInsertTable));
      await tester.pumpAndSettle();
      expect(bridge.commands.last, EditorCommand.insertTable(rows: 3, cols: 3));

      bridge.emit(
        const EditorStateChanged(
          EditorState(active: EditorActive(table: true)),
        ),
      );
      await tester.pump();
      for (final (label, command) in [
        (en.editorAddRow, EditorCommandName.addRowAfter),
        (en.editorAddColumn, EditorCommandName.addColumnAfter),
        (en.editorDeleteRow, EditorCommandName.deleteRow),
        (en.editorDeleteColumn, EditorCommandName.deleteColumn),
        (en.editorDeleteTable, EditorCommandName.deleteTable),
      ]) {
        await tapTool(tester, en.editorTable);
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(bridge.commands.last, EditorCommand(command), reason: label);
      }
    });

    testWidgets('undo and redo follow what the page says is possible', (
      tester,
    ) async {
      await openEditor(tester);
      final bridge = bridges.last;
      IconButton button(String tooltip) => tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip(tooltip),
          matching: find.byType(IconButton),
        ),
      );
      expect(button(en.editorUndo).onPressed, isNull);
      expect(button(en.editorRedo).onPressed, isNull);

      bridge.emit(
        const EditorStateChanged(EditorState(canUndo: true, canRedo: true)),
      );
      await tester.pump();
      await tapTool(tester, en.editorUndo);
      await tapTool(tester, en.editorRedo);

      expect(bridge.commands, [
        const EditorCommand(EditorCommandName.undo),
        const EditorCommand(EditorCommandName.redo),
      ]);
    });

    testWidgets('the marks and blocks at the cursor show as toggled', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await openEditor(tester);

      expect(
        tester.getSemantics(find.byTooltip(en.editorBold)),
        isSemantics(hasToggledState: true, isToggled: false, isButton: true),
      );
      bridges.last.emit(
        const EditorStateChanged(
          EditorState(active: EditorActive(bold: true, link: true, heading: 2)),
        ),
      );
      await tester.pump();

      expect(
        tester.getSemantics(find.byTooltip(en.editorBold)),
        isSemantics(
          tooltip: en.editorBold,
          hasToggledState: true,
          isToggled: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.byTooltip(en.editorLink)),
        isSemantics(isToggled: true),
      );
      expect(
        tester.getSemantics(find.byTooltip(en.editorItalic)),
        isSemantics(isToggled: false),
      );
      expect(
        tester.getSemantics(find.byTooltip(en.editorTextStyle)),
        isSemantics(value: en.editorHeading(2)),
      );
      semantics.dispose();
    });

    testWidgets('the link button adds a link in a sheet', (tester) async {
      await openEditor(tester);
      final bridge = bridges.last;

      await tapTool(tester, en.editorLink);
      expect(find.text(en.editorLinkAddTitle), findsOneWidget);
      await tester.enterText(find.byType(TextField), ' https://example.org ');
      await tester.pump();
      await tester.tap(find.text(en.editorLinkApply));
      await tester.pumpAndSettle();

      expect(bridge.commands, [EditorCommand.setLink('https://example.org')]);
      expect(bridge.focusCalls, 2);
    });

    testWidgets('on a link the sheet opens with its address: Apply keeps the '
        'link, Remove link removes it', (tester) async {
      await openEditor(tester);
      final bridge = bridges.last
        ..emit(
          const EditorStateChanged(
            EditorState(
              active: EditorActive(
                link: true,
                linkHref: 'https://old.example.org',
              ),
            ),
          ),
        );
      await tester.pump();

      await tapTool(tester, en.editorLink);
      expect(find.text(en.editorLinkEditTitle), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'https://old.example.org',
      );
      await tester.tap(find.text(en.editorLinkApply));
      await tester.pumpAndSettle();
      expect(bridge.commands, [
        EditorCommand.setLink('https://old.example.org'),
      ]);

      await tapTool(tester, en.editorLink);
      await tester.tap(find.text(en.editorLinkRemove));
      await tester.pumpAndSettle();
      expect(
        bridge.commands.last,
        const EditorCommand(EditorCommandName.unsetLink),
      );
    });

    testWidgets('the menus leave the focus with the editor', (tester) async {
      await openEditor(tester);

      final menus = tester.widgetList<PopupMenuButton<Object?>>(
        find.byWidgetPredicate((widget) => widget is PopupMenuButton),
      );
      // Text style, image and table.
      expect(menus, hasLength(3));
      for (final menu in menus) {
        expect(menu.requestFocus, isFalse);
      }
    });
  });

  group('mentions', () {
    testWidgets("an @ suggests the project's people from the server; a tap "
        'mentions one', (tester) async {
      await openEditor(tester);
      final bridge = bridges.last..emit(const MentionQuery('ja'));
      await tester.pump();
      expect(find.byType(MentionBar), findsOneWidget);
      expect(find.text(en.editorMentionsSearching), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(users.searches, [(1, 'ja')]);
      expect(find.text('Jane Doe'), findsOneWidget);
      expect(find.text('@jdoe'), findsOneWidget);
      await tester.tap(find.text('Jane Doe'));
      await tester.pumpAndSettle();

      expect(bridge.mentions, [
        const EditorMention(username: 'jdoe', label: 'Jane Doe'),
      ]);
      expect(find.byType(MentionBar), findsNothing);
    });

    testWidgets('screen readers hear how many people were found', (
      tester,
    ) async {
      await openEditor(tester);
      tester.takeAnnouncements();

      bridges.last.emit(const MentionQuery('j'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.editorMentionsFound(2)),
      ]);
    });

    for (final (name, size, keyboard) in [
      ('portrait', const Size(360, 640), 280.0),
      ('landscape', const Size(640, 360), 170.0),
    ]) {
      testWidgets('above the keyboard in $name at 200 % the suggestions leave '
          'the editor room and the toolbar in sight', (tester) async {
        useAccessibilityExtremes(tester);
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);
        users = FakeUserRepository(
          projectUsers: {
            1: [
              for (var i = 0; i < 8; i++)
                User(id: 20 + i, username: 'person$i', name: 'Person $i'),
            ],
          },
        );
        await openEditor(tester, size: size);

        bridges.last.emit(const MentionQuery(''));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(MentionBar), findsOneWidget);
        final editor = tester.getRect(find.byKey(FakeEditorBridge.viewKey));
        final bar = tester.getRect(find.byType(MentionBar));
        final toolbar = tester.getRect(find.byType(EditorToolbar));
        // Two lines of the page's text at 200 %, or at least half of what
        // the toolbar leaves when that is less.
        expect(
          editor.height,
          greaterThanOrEqualTo(
            math.min(12 + 2 * 24 * 2, (editor.height + bar.height) / 2),
          ),
        );
        expect(bar.height, greaterThan(0));
        expect(toolbar.bottom, lessThanOrEqualTo(size.height - keyboard));
      });
    }

    testWidgets('offline the people this device knows are suggested', (
      tester,
    ) async {
      users.searchFailure = const NetworkFailure(NetworkProblem.unreachable);
      await openEditor(tester);

      bridges.last.emit(const MentionQuery('doe'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text(en.editorMentionsFromDevice), findsOneWidget);
      expect(find.text('Jane Doe'), findsOneWidget);
      expect(find.text('john'), findsNothing);
    });

    testWidgets('nobody found says so, and the end of the mention hides it', (
      tester,
    ) async {
      await openEditor(tester);

      bridges.last.emit(const MentionQuery('zz'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text(en.editorMentionsNone), findsOneWidget);

      bridges.last.emit(const MentionEnd());
      await tester.pumpAndSettle();
      expect(find.byType(MentionBar), findsNothing);
    });
  });

  test('the suggestions take what the editor can spare, at most half', () {
    double max(double available) => DescriptionEditorPage.mentionBarMaxHeight(
      available: available,
      toolbarHeight: 56,
      editorMinHeight: 60,
    );
    expect(max(290), 117);
    expect(max(1000), 472);
    expect(max(400), 172);
    expect(max(110), 27);
    expect(max(40), 0);
  });

  group('saving', () {
    testWidgets('Save queues the edit with the description it started from '
        'and closes', (tester) async {
      final result = await openEditor(tester);
      bridges.last.edit('<p>Numbers and charts</p>');
      await tester.pump();
      expect(saveEnabled(tester), isTrue);

      await tester.tap(saveButton());
      await tester.pumpAndSettle();

      expect(data.tasks.descriptionUpdates, [
        (1, '<p>Numbers and charts</p>', '<p>Numbers</p>'),
      ]);
      expect(find.byType(DescriptionEditorPage), findsNothing);
      expect(result, [isTrue]);
    });

    testWidgets('an emptied document for a description never written '
        'changes nothing', (tester) async {
      final result = await openEditor(
        tester,
        route: AppRoutes.taskDescription(2),
      );
      bridges.last.edit('<p></p>');
      await tester.pump();

      await tester.tap(saveButton());
      await tester.pumpAndSettle();

      expect(data.tasks.descriptionUpdates, isEmpty);
      expect(result, [isFalse]);
    });

    testWidgets('an unchanged editor leaves without asking or writing', (
      tester,
    ) async {
      final result = await openEditor(tester);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(DescriptionEditorPage), findsNothing);
      expect(bridges.last.htmlCalls, 0);
      expect(data.tasks.descriptionUpdates, isEmpty);
      expect(data.tasks.writes, isEmpty);
      expect(result, [isNull]);
    });

    testWidgets('leaving with changes asks: keep editing, discard or save', (
      tester,
    ) async {
      await openEditor(tester);
      bridges.last.edit('<p>Edited</p>');
      await tester.pump();

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text(en.descriptionEditorLeaveTitle), findsOneWidget);
      await tester.tap(find.text(en.taskEditKeepEditing));
      await tester.pumpAndSettle();
      expect(find.byType(DescriptionEditorPage), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text(en.taskEditSave),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DescriptionEditorPage), findsNothing);
      expect(data.tasks.descriptionUpdates, [
        (1, '<p>Edited</p>', '<p>Numbers</p>'),
      ]);
    });

    testWidgets('Save goes by what the page answers, not by its last state: '
        'a document clean again writes nothing', (tester) async {
      final result = await openEditor(tester);
      final bridge = bridges.last..edit('<p>Edited</p>');
      await tester.pump();
      bridge
        ..document = '<p>Numbers</p>'
        ..dirty = false;

      await tester.tap(saveButton());
      await tester.pumpAndSettle();

      expect(bridge.htmlCalls, 1);
      expect(data.tasks.descriptionUpdates, isEmpty);
      expect(result, [isFalse]);
    });

    testWidgets('while saving the page takes no input; when the save does not '
        'close it, editing goes on', (tester) async {
      data.projects.failure = const NetworkFailure(NetworkProblem.unreachable);
      await openEditor(tester, route: AppRoutes.projectDescription(1));
      final bridge = bridges.last..edit('<p>About work, edited</p>');
      await tester.pump();

      await tester.tap(saveButton());
      await tester.pumpAndSettle();

      expect(bridge.readOnly, [true, false]);
      expect(find.byType(DescriptionEditorPage), findsOneWidget);
    });

    testWidgets('a page that is clean again by the time Save is chosen '
        'writes nothing', (tester) async {
      final result = await openEditor(tester);
      final bridge = bridges.last..edit('<p>Edited</p>');
      await tester.pump();

      await tester.pageBack();
      await tester.pumpAndSettle();
      bridge.emit(const EditorStateChanged(EditorState()));
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text(en.taskEditSave),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DescriptionEditorPage), findsNothing);
      expect(data.tasks.descriptionUpdates, isEmpty);
      expect(result, [isFalse]);
    });

    testWidgets('discarding leaves the description as it is', (tester) async {
      final result = await openEditor(tester);
      bridges.last.edit('<p>Edited</p>');
      await tester.pump();

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.taskEditDiscard));
      await tester.pumpAndSettle();

      expect(find.byType(DescriptionEditorPage), findsNothing);
      expect(data.tasks.descriptionUpdates, isEmpty);
      expect(data.tasks.find(1)!.description, '<p>Numbers</p>');
      expect(result, [isFalse]);
    });

    testWidgets('a description changed meanwhile asks first; Overwrite '
        'saves over it', (tester) async {
      await openEditor(tester);
      bridges.last.edit('<p>Mine</p>');
      data.tasks.all = [
        data.tasks.find(1)!.copyWith(description: '<p>From the web</p>'),
        data.tasks.find(2)!,
      ];
      await tester.pump();

      await tester.tap(saveButton());
      await tester.pumpAndSettle();
      expect(find.text(en.descriptionEditorChangedTitle), findsOneWidget);
      expect(data.tasks.descriptionUpdates, isEmpty);
      await tester.tap(find.text(en.descriptionEditorOverwrite));
      await tester.pumpAndSettle();

      expect(data.tasks.descriptionUpdates, [
        (1, '<p>Mine</p>', '<p>From the web</p>'),
      ]);
      expect(find.byType(DescriptionEditorPage), findsNothing);
    });

    testWidgets('Reload opens the changed description instead and writes '
        'nothing', (tester) async {
      await openEditor(tester);
      final first = bridges.last..edit('<p>Mine</p>');
      data.tasks.all = [
        data.tasks.find(1)!.copyWith(description: '<p>From the web</p>'),
        data.tasks.find(2)!,
      ];
      await tester.pump();

      await tester.tap(saveButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.descriptionEditorReload));
      await tester.pumpAndSettle();

      expect(first.disposed, isTrue);
      expect(bridges.created, hasLength(2));
      expect(bridges.last.init!.html, '<p>From the web</p>');
      expect(data.tasks.descriptionUpdates, isEmpty);
      expect(find.byType(DescriptionEditorPage), findsOneWidget);
      expect(saveEnabled(tester), isFalse);

      bridges.last.edit('<p>From the web, and mine</p>');
      await tester.pump();
      await tester.tap(saveButton());
      await tester.pumpAndSettle();
      expect(data.tasks.descriptionUpdates, [
        (1, '<p>From the web, and mine</p>', '<p>From the web</p>'),
      ]);
    });

    testWidgets(
      'on iOS the changed-meanwhile dialog can be left: nothing is written and '
      'editing goes on',
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      (tester) async {
        await openEditor(tester);
        final bridge = bridges.last..edit('<p>Mine</p>');
        data.tasks.all = [
          data.tasks.find(1)!.copyWith(description: '<p>From the web</p>'),
          data.tasks.find(2)!,
        ];
        await tester.pump();

        await tester.tap(saveButton());
        await tester.pumpAndSettle();
        expect(find.text(en.descriptionEditorChangedTitle), findsOneWidget);
        await tester.tap(find.text(en.taskEditKeepEditing));
        await tester.pumpAndSettle();

        expect(data.tasks.descriptionUpdates, isEmpty);
        expect(bridges.created, hasLength(1));
        expect(find.byType(DescriptionEditorPage), findsOneWidget);
        expect(bridge.readOnly, [true, false]);
        expect(saveEnabled(tester), isTrue);
      },
    );

    testWidgets('leaving an editor whose task has gone offers no Save', (
      tester,
    ) async {
      await openEditor(tester);
      bridges.last.edit('<p>Edited</p>');
      data.tasks.all = [data.tasks.find(2)!];
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text(en.descriptionEditorLeaveTitle), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text(en.taskEditSave),
        ),
        findsNothing,
      );
      await tester.tap(find.text(en.taskEditDiscard));
      await tester.pumpAndSettle();
      expect(data.tasks.descriptionUpdates, isEmpty);
    });

    testWidgets('a page that does not answer keeps the editor open', (
      tester,
    ) async {
      await openEditor(tester);
      bridges.last
        ..edit('<p>Edited</p>')
        ..htmlFailure = TimeoutException('no answer');
      await tester.pump();

      await tester.tap(saveButton());
      await tester.pumpAndSettle();

      expect(find.text(en.descriptionEditorSaveFailed), findsOneWidget);
      expect(find.byType(DescriptionEditorPage), findsOneWidget);
      expect(data.tasks.descriptionUpdates, isEmpty);
      expect(saveEnabled(tester), isTrue);
    });
  });

  group('a WebView that stops', () {
    testWidgets('after edits Reload goes on from the copy, and Save writes it '
        'over the description it started from', (tester) async {
      final result = await openEditor(tester);
      bridges.last.edit('<p>Mine</p>');
      await tester.pump(DescriptionEditorPage.copyDelay);
      await tester.pump();

      bridges.last.emit(const EditorStopped());
      await tester.pumpAndSettle();
      expect(find.text(en.descriptionEditorStoppedKept), findsOneWidget);

      await tester.tap(find.text(en.descriptionEditorReload));
      await tester.pumpAndSettle();
      expect(bridges.created, hasLength(2));
      expect(bridges.last.init!.html, '<p>Mine</p>');
      expect(saveEnabled(tester), isTrue);

      await tester.tap(saveButton());
      await tester.pumpAndSettle();
      expect(data.tasks.descriptionUpdates, [
        (1, '<p>Mine</p>', '<p>Numbers</p>'),
      ]);
      expect(result, [isTrue]);
    });

    testWidgets('leaving with a copy asks, and Save writes the copy', (
      tester,
    ) async {
      await openEditor(tester);
      bridges.last.edit('<p>Mine</p>');
      await tester.pump(DescriptionEditorPage.copyDelay);
      await tester.pump();
      bridges.last.emit(const EditorStopped());
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text(en.taskEditSave),
        ),
      );
      await tester.pumpAndSettle();

      expect(data.tasks.descriptionUpdates, [
        (1, '<p>Mine</p>', '<p>Numbers</p>'),
      ]);
    });

    testWidgets('before a copy was taken it says the changes are lost; Reload '
        'starts from the description', (tester) async {
      await openEditor(tester);
      bridges.last.edit('<p>Mine</p>');
      await tester.pump();

      bridges.last.emit(const EditorStopped());
      await tester.pumpAndSettle();
      expect(find.text(en.descriptionEditorStoppedLost), findsOneWidget);
      expect(saveEnabled(tester), isFalse);

      await tester.tap(find.text(en.descriptionEditorReload));
      await tester.pumpAndSettle();
      expect(bridges.last.init!.html, '<p>Numbers</p>');
      expect(saveEnabled(tester), isFalse);
    });
  });

  group('drafts', () {
    void toForeground(WidgetTester tester) {
      if (tester.binding.lifecycleState == AppLifecycleState.resumed) return;
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }

    Future<void> toBackground(WidgetTester tester) async {
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      addTearDown(() => toForeground(tester));
      await tester.pumpAndSettle();
    }

    testWidgets('going to the background keeps the edit, which an editor '
        'opened after a restart offers back', (tester) async {
      await openEditor(tester);
      bridges.last.edit('<p>Draft</p>');
      await tester.pump();

      await toBackground(tester);
      final kept = auth.preferences.values[DescriptionDrafts.key];
      expect(kept, isNotNull);
      expect(jsonDecode(kept!), containsPair('html', '<p>Draft</p>'));
      expect(data.tasks.descriptionUpdates, isEmpty);
      toForeground(tester);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.taskEditDiscard));
      await tester.pumpAndSettle();
      expect(auth.preferences.values[DescriptionDrafts.key], isNull);

      // As if the system had ended the app while it was in the background.
      auth.preferences.values[DescriptionDrafts.key] = kept;
      await openEditor(tester, pumpApp: false, settle: false);
      await pumpFrames(tester, 10);
      expect(find.text(en.descriptionEditorRestoreTitle), findsOneWidget);
      await tester.tap(find.text(en.descriptionEditorRestore));
      await tester.pumpAndSettle();

      expect(bridges.last.init!.html, '<p>Draft</p>');
      await tester.tap(saveButton());
      await tester.pumpAndSettle();
      expect(data.tasks.descriptionUpdates, [
        (1, '<p>Draft</p>', '<p>Numbers</p>'),
      ]);
      expect(auth.preferences.values[DescriptionDrafts.key], isNull);
    });

    testWidgets('a declined draft is dropped, and one for another '
        'description is not offered', (tester) async {
      await openEditor(tester);
      bridges.last.edit('<p>Draft</p>');
      await tester.pump();
      await toBackground(tester);
      final kept = auth.preferences.values[DescriptionDrafts.key]!;
      toForeground(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.taskEditDiscard));
      await tester.pumpAndSettle();

      auth.preferences.values[DescriptionDrafts.key] = kept;
      await openEditor(
        tester,
        route: AppRoutes.taskDescription(2),
        pumpApp: false,
      );
      expect(find.text(en.descriptionEditorRestoreTitle), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(auth.preferences.values[DescriptionDrafts.key], kept);

      await openEditor(tester, pumpApp: false, settle: false);
      await pumpFrames(tester, 10);
      await tester.tap(find.text(en.taskEditDiscard));
      await tester.pumpAndSettle();
      expect(bridges.last.init!.html, '<p>Numbers</p>');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(auth.preferences.values[DescriptionDrafts.key], isNull);
    });
  });

  group('project description', () {
    testWidgets('is saved on the server with the other project fields', (
      tester,
    ) async {
      final result = await openEditor(
        tester,
        route: AppRoutes.projectDescription(1),
      );
      expect(bridges.last.init!.html, '<p>About work</p>');
      bridges.last.edit('<p>About work, edited</p>');
      await tester.pump();

      await tester.tap(saveButton());
      await tester.pumpAndSettle();

      expect(data.projects.updates, [
        (1, const ProjectChanges(description: '<p>About work, edited</p>')),
      ]);
      expect(data.projects.find(1)!.description, '<p>About work, edited</p>');
      expect(result, [isTrue]);
    });

    testWidgets('a refusal keeps the editor open and says why', (tester) async {
      data.projects.failure = const NetworkFailure(NetworkProblem.unreachable);
      await openEditor(tester, route: AppRoutes.projectDescription(1));
      bridges.last.edit('<p>About work, edited</p>');
      await tester.pump();

      await tester.tap(saveButton());
      await tester.pumpAndSettle();

      expect(find.byType(DescriptionEditorPage), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(data.projects.find(1)!.description, '<p>About work</p>');
    });

    testWidgets('changed on the web meanwhile asks first; Overwrite saves '
        'over exactly that change', (tester) async {
      await openEditor(tester, route: AppRoutes.projectDescription(1));
      bridges.last.edit('<p>Mine</p>');
      data.projects.webDescriptions[1] = '<p>From the web</p>';
      await tester.pump();

      await tester.tap(saveButton());
      await tester.pumpAndSettle();
      expect(find.text(en.descriptionEditorChangedTitle), findsOneWidget);
      expect(data.projects.updates, isEmpty);
      await tester.tap(find.text(en.descriptionEditorOverwrite));
      await tester.pumpAndSettle();

      expect(data.projects.descriptionBases, [
        '<p>About work</p>',
        '<p>From the web</p>',
      ]);
      expect(data.projects.find(1)!.description, '<p>Mine</p>');
      expect(find.byType(DescriptionEditorPage), findsNothing);
    });

    testWidgets('changed on the web meanwhile, Reload opens the web '
        'version', (tester) async {
      await openEditor(tester, route: AppRoutes.projectDescription(1));
      bridges.last.edit('<p>Mine</p>');
      data.projects.webDescriptions[1] = '<p>From the web</p>';
      await tester.pump();

      await tester.tap(saveButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.descriptionEditorReload));
      await tester.pumpAndSettle();

      expect(bridges.last.init!.html, '<p>From the web</p>');
      expect(data.projects.updates, isEmpty);
      expect(find.byType(DescriptionEditorPage), findsOneWidget);
    });

    testWidgets("mentions search the project's own people", (tester) async {
      await openEditor(tester, route: AppRoutes.projectDescription(1));

      bridges.last.emit(const MentionQuery('jo'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(users.searches, [(1, 'jo')]);
      expect(find.text('john'), findsOneWidget);
    });
  });

  testWidgets('a task gone while editing says so', (tester) async {
    await openEditor(tester);

    data.tasks.all = [data.tasks.find(2)!];
    await tester.pumpAndSettle();

    expect(find.text(en.taskEditGoneTitle), findsOneWidget);
  });
}
