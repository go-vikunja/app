import 'dart:typed_data';

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/attachments/attachment_images.dart';
import 'package:vikunja_mobile/features/tasks/presentation/rich_text/attachment_image_viewer.dart';
import 'package:vikunja_mobile/features/tasks/presentation/rich_text/rich_text_view.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';
import '../../helpers/task_details_fakes.dart';

const _anna = User(id: 9, username: 'anna', name: 'Anna');

const photo = RichImage(
  RichAttachmentImage(AttachmentRef(taskId: 5, attachmentId: 3)),
  alt: 'The fence',
);

final class _Taps {
  final links = <String>[];
  final tasks = <int>[];
  final taskItems = <RichTaskItem>[];
}

void main() {
  late SyncFakes data;

  setUp(() {
    data = SyncFakes();
    data.projects.all = [
      sampleProject(id: 1, title: 'Work', identifier: 'WORK'),
      sampleProject(id: 2, title: 'Home'),
    ];
    data.tasks.all = [
      sampleTask(id: 5, title: 'Pay rent'),
      sampleTask(id: 6, title: 'Paint the fence', projectId: 2, done: true),
    ];
  });

  /// [document] on a page of its own over the signed-in app, with every
  /// provider the views read.
  Future<_Taps> pumpRichText(
    WidgetTester tester,
    List<RichBlock> blocks, {
    int? projectId = 1,
    User? Function(int commentId)? replyAuthorOf,
    bool toggleable = false,
  }) async {
    usePhoneSurface(tester, logicalSize: const Size(360, 1600));
    await pumpSignedInApp(tester, sync: data);
    final taps = _Taps();
    containerOf(tester)
        .read(appRouterProvider)
        .routerDelegate
        .navigatorKey
        .currentState!
        .push(
          MaterialPageRoute<void>(
            builder: (context) => Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectionArea(
                  child: RichTextView(
                    document: RichDocument(blocks),
                    onLink: taps.links.add,
                    onTaskLink: taps.tasks.add,
                    onToggleTaskItem: toggleable ? taps.taskItems.add : null,
                    projectId: projectId,
                    replyAuthorOf: replyAuthorOf,
                  ),
                ),
              ),
            ),
          ),
        );
    await tester.pumpAndSettle();
    return taps;
  }

  /// The style [text] is painted with: its span's merged over its
  /// paragraph's.
  TextStyle styleOf(WidgetTester tester, String text) {
    for (final paragraph in tester.widgetList<RichText>(
      find.byType(RichText),
    )) {
      TextStyle? found;
      void visit(InlineSpan span, TextStyle inherited) {
        final style = inherited.merge(span.style);
        if (span is TextSpan) {
          if (span.text == text) found = style;
          for (final child in span.children ?? const <InlineSpan>[]) {
            visit(child, style);
          }
        }
      }

      visit(paragraph.text, const TextStyle());
      if (found != null) return found!;
    }
    throw TestFailure('No span with "$text"');
  }

  group('blocks', () {
    testWidgets('paragraphs and headings, headings announced as such', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpRichText(tester, const [
        RichHeading(1, [RichTextRun('Plan')]),
        RichParagraph([RichTextRun('First '), RichTextRun('line')]),
        RichHeading(3, [RichTextRun('Details')]),
      ]);

      expect(find.text('First line'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Plan')),
        matchesSemantics(label: 'Plan', isHeader: true),
      );
      expect(
        tester.getSemantics(find.text('Details')),
        matchesSemantics(label: 'Details', isHeader: true),
      );
      // The platforms take only the level for a heading.
      expect(
        tester.getSemantics(find.text('Plan')).getSemanticsData().headingLevel,
        1,
      );
      expect(
        tester
            .getSemantics(find.text('Details'))
            .getSemanticsData()
            .headingLevel,
        3,
      );
      semantics.dispose();
    });

    testWidgets('bullet and ordered lists, nested, from their start', (
      tester,
    ) async {
      await pumpRichText(tester, const [
        RichBulletList([
          RichListItem([
            RichParagraph([RichTextRun('Milk')]),
            RichBulletList([
              RichListItem([
                RichParagraph([RichTextRun('Oat')]),
              ]),
            ]),
          ]),
        ]),
        RichOrderedList([
          RichListItem([
            RichParagraph([RichTextRun('Third')]),
          ]),
          RichListItem([
            RichParagraph([RichTextRun('Fourth')]),
          ]),
        ], start: 3),
      ]);

      expect(find.text('•'), findsOneWidget);
      expect(find.text('◦'), findsOneWidget);
      expect(find.text('Oat'), findsOneWidget);
      expect(find.text('3.'), findsOneWidget);
      expect(find.text('4.'), findsOneWidget);
      expect(find.text('Fourth'), findsOneWidget);
    });

    testWidgets('task lists with a toggle: items with a source offset take '
        'taps on their checkbox, one with a link keeps it apart', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      const nested = RichTaskItem(
        checked: false,
        sourceOffset: 120,
        blocks: [
          RichParagraph([RichTextRun('Second coat')]),
        ],
      );
      const withLink = RichTaskItem(
        checked: true,
        sourceOffset: 200,
        blocks: [
          RichParagraph([
            RichTextRun('Ask '),
            RichTextRun('Anna', href: 'https://example.org/anna'),
          ]),
        ],
      );
      final taps = await pumpRichText(tester, toggleable: true, const [
        RichTaskList([
          RichTaskItem(
            checked: false,
            sourceOffset: 10,
            blocks: [
              RichParagraph([RichTextRun('Paint')]),
              RichTaskList([nested]),
            ],
          ),
          withLink,
          RichTaskItem(
            checked: true,
            blocks: [
              RichParagraph([RichTextRun('Legacy')]),
            ],
          ),
        ]),
      ]);

      expect(
        tester.getSemantics(find.text('Paint')),
        isSemantics(
          label: 'Paint',
          hasCheckedState: true,
          isChecked: false,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Ask Anna')),
        isSemantics(hasCheckedState: true, isChecked: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(find.text('Legacy')),
        isSemantics(hasCheckedState: true, hasTapAction: false),
      );
      for (final size in [
        for (final element in find.byType(InkResponse).evaluate())
          element.size!,
      ]) {
        expect(size, const Size.square(48));
      }

      await tester.tap(find.byIcon(Icons.check_box_outline_blank).last);
      await tester.tap(find.byIcon(Icons.check_box).first);
      await tester.tap(find.byIcon(Icons.check_box).last);
      await tester.tapOnText(find.textRange.ofSubstring('Anna'));
      await tester.pump();

      expect(taps.taskItems, [nested, withLink]);
      expect(taps.links, ['https://example.org/anna']);
      semantics.dispose();
    });

    testWidgets('task lists: read-only checkboxes with their state, the '
        'checked text struck through and dimmed', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpRichText(tester, const [
        RichTaskList([
          RichTaskItem(
            checked: true,
            blocks: [
              RichParagraph([RichTextRun('Buy paint')]),
            ],
          ),
          RichTaskItem(
            checked: false,
            blocks: [
              RichParagraph([RichTextRun('Paint')]),
              RichTaskList([
                RichTaskItem(
                  checked: false,
                  blocks: [
                    RichParagraph([RichTextRun('Second coat')]),
                  ],
                ),
              ]),
            ],
          ),
        ]),
      ]);

      expect(
        tester.getSemantics(find.text('Buy paint')),
        matchesSemantics(
          label: 'Buy paint',
          hasCheckedState: true,
          isChecked: true,
        ),
      );
      expect(
        tester.getSemantics(find.text('Paint')),
        matchesSemantics(label: 'Paint', hasCheckedState: true),
      );
      expect(
        tester.getSemantics(find.text('Second coat')),
        matchesSemantics(label: 'Second coat', hasCheckedState: true),
      );
      expect(find.byIcon(Icons.check_box), findsOneWidget);
      expect(find.byIcon(Icons.check_box_outline_blank), findsNWidgets(2));
      final checked = styleOf(tester, 'Buy paint');
      expect(checked.decoration, TextDecoration.lineThrough);
      expect(
        styleOf(tester, 'Paint').decoration,
        isNot(TextDecoration.lineThrough),
      );
      semantics.dispose();
    });

    testWidgets("a reply quote names the quoted comment's author when it is "
        'loaded, otherwise it is a plain quote', (tester) async {
      await pumpRichText(tester, const [
        RichBlockquote([
          RichParagraph([RichTextRun('Sounds good')]),
        ], commentId: 1),
        RichBlockquote([
          RichParagraph([RichTextRun('Older')]),
        ], commentId: 2),
      ], replyAuthorOf: (id) => id == 1 ? _anna : null);

      expect(find.text(en.richTextReplyTo('Anna')), findsOneWidget);
      expect(find.text('Sounds good'), findsOneWidget);
      expect(find.text('Older'), findsOneWidget);
    });

    testWidgets('code blocks keep their whitespace in monospace and scroll '
        'sideways; rules draw a line', (tester) async {
      const code = 'void main() {\n  print(1);\n}';
      await pumpRichText(tester, const [
        RichCodeBlock(code, language: 'dart'),
        RichHorizontalRule(),
      ]);

      final text = tester.widget<Text>(find.text(code));
      expect(text.style?.fontFamily, 'monospace');
      expect(
        find.ancestor(
          of: find.text(code),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SingleChildScrollView &&
                widget.scrollDirection == Axis.horizontal,
          ),
        ),
        findsOneWidget,
      );
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('tables scroll sideways with emphasised header cells, valid '
        'cell colours and spans filled out', (tester) async {
      await pumpRichText(tester, const [
        RichTable([
          RichTableRow([
            RichTableCell(
              header: true,
              blocks: [
                RichParagraph([RichTextRun('Item')]),
              ],
            ),
            RichTableCell(
              header: true,
              blocks: [
                RichParagraph([RichTextRun('Cost')]),
              ],
            ),
          ]),
          RichTableRow([
            RichTableCell(
              colspan: 2,
              backgroundColor: 0xFFFF0000,
              blocks: [
                RichParagraph([RichTextRun('Total')]),
              ],
            ),
          ]),
          RichTableRow([
            RichTableCell(
              blocks: [
                RichCodeBlock('x = 1'),
                RichTable([
                  RichTableRow([
                    RichTableCell(
                      blocks: [
                        RichParagraph([RichTextRun('Inner')]),
                      ],
                    ),
                  ]),
                ]),
              ],
            ),
          ]),
        ]),
      ]);

      expect(tester.takeException(), isNull);
      expect(styleOf(tester, 'Item').fontWeight, FontWeight.bold);
      expect(styleOf(tester, 'Total').fontWeight, isNot(FontWeight.bold));
      final table = tester.widget<Table>(find.byType(Table));
      expect(table.children, hasLength(3));
      expect(table.children.every((row) => row.children.length == 2), isTrue);
      expect(
        find.ancestor(
          of: find.text('Total'),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is ColoredBox && widget.color == const Color(0xFFFF0000),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.byType(Table),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SingleChildScrollView &&
                widget.scrollDirection == Axis.horizontal,
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('x = 1'), findsOneWidget);
      expect(find.text('Inner'), findsOneWidget);
    });

    RichTableCell cell(String text, {int colspan = 1, int rowspan = 1}) =>
        RichTableCell(
          colspan: colspan,
          rowspan: rowspan,
          blocks: [
            RichParagraph([RichTextRun(text)]),
          ],
        );

    Finder inGridCell(Table table, int row, int column, String text) =>
        find.descendant(
          of: find.byWidget(table.children[row].children[column]),
          matching: find.text(text),
        );

    testWidgets('a row span keeps the cells below it in their columns', (
      tester,
    ) async {
      await pumpRichText(tester, [
        RichTable([
          RichTableRow([cell('Q1', rowspan: 2), cell('Revenue')]),
          RichTableRow([cell('Costs')]),
          RichTableRow([cell('Q2'), cell('Revenue 2'), cell('Extra')]),
        ]),
      ]);

      final table = tester.widget<Table>(find.byType(Table));
      expect(table.children.map((row) => row.children.length), [3, 3, 3]);
      expect(inGridCell(table, 0, 0, 'Q1'), findsOneWidget);
      expect(inGridCell(table, 1, 1, 'Costs'), findsOneWidget);
      expect(inGridCell(table, 2, 2, 'Extra'), findsOneWidget);
      expect(find.text('Q1'), findsOneWidget);
    });

    testWidgets('a small table with spans stays a table', (tester) async {
      await pumpRichText(tester, [
        RichTable([
          RichTableRow([cell('Wide', colspan: 3)]),
          RichTableRow([cell('a'), cell('b'), cell('c')]),
        ]),
      ]);

      final table = tester.widget<Table>(find.byType(Table));
      expect(table.children.map((row) => row.children.length), [3, 3]);
    });

    for (final (name, html) in [
      (
        'a thousand cells spanning a thousand columns',
        '<table><tr>${'<td colspan="1000"></td>' * 1000}</tr></table>',
      ),
      (
        'one wide cell over a thousand rows',
        '<table><tr><td colspan="1000">wide</td></tr>'
            '${'<tr><td>x</td></tr>' * 1000}</table>',
      ),
    ]) {
      testWidgets('$name is shown row by row, not as a grid', (tester) async {
        final document = parseRichText(
          html,
          apiRoot: Uri.parse('https://tasks.example.org/vikunja/'),
          taskLinkBases: const [],
        );
        await pumpRichText(tester, document.blocks);

        expect(find.byType(Table), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('headings are bold, larger than the body and ordered by '
        'level', (tester) async {
      await pumpRichText(tester, const [
        RichHeading(1, [RichTextRun('One')]),
        RichHeading(2, [RichTextRun('Two')]),
        RichHeading(3, [RichTextRun('Three')]),
        RichHeading(4, [RichTextRun('Four')]),
        RichParagraph([RichTextRun('Body')]),
      ]);

      final sizes = [
        for (final text in ['One', 'Two', 'Three', 'Four', 'Body'])
          styleOf(tester, text).fontSize!,
      ];
      for (var i = 1; i < sizes.length; i++) {
        expect(sizes[i - 1], greaterThanOrEqualTo(sizes[i]));
      }
      expect(sizes[2], greaterThan(sizes[3]));
      for (final text in ['One', 'Two', 'Three', 'Four']) {
        expect(styleOf(tester, text).fontWeight, FontWeight.bold);
      }
    });
  });

  group('marks', () {
    testWidgets('every mark changes the style', (tester) async {
      await pumpRichText(tester, const [
        RichParagraph([
          RichTextRun('bold', marks: {RichMark.bold}),
          RichTextRun('italic', marks: {RichMark.italic}),
          RichTextRun('under', marks: {RichMark.underline}),
          RichTextRun('struck', marks: {RichMark.strike}),
          RichTextRun('both', marks: {RichMark.underline, RichMark.strike}),
          RichTextRun('code', marks: {RichMark.code}),
          RichTextRun('sub', marks: {RichMark.subscript}),
          RichTextRun('sup', marks: {RichMark.superscript}),
          RichTextRun('plain'),
        ]),
      ]);

      final plain = styleOf(tester, 'plain');
      expect(styleOf(tester, 'bold').fontWeight, FontWeight.bold);
      expect(styleOf(tester, 'italic').fontStyle, FontStyle.italic);
      expect(styleOf(tester, 'under').decoration, TextDecoration.underline);
      expect(styleOf(tester, 'struck').decoration, TextDecoration.lineThrough);
      expect(
        styleOf(tester, 'both').decoration,
        TextDecoration.combine([
          TextDecoration.underline,
          TextDecoration.lineThrough,
        ]),
      );
      expect(styleOf(tester, 'code').fontFamily, 'monospace');
      expect(styleOf(tester, 'code').backgroundColor, isNotNull);
      expect(styleOf(tester, 'sub').fontSize, lessThan(plain.fontSize!));
      expect(styleOf(tester, 'sub').fontFeatures, [
        const FontFeature.subscripts(),
      ]);
      expect(styleOf(tester, 'sup').fontFeatures, [
        const FontFeature.superscripts(),
      ]);
      expect(plain.fontWeight, isNot(FontWeight.bold));
      expect(plain.decoration, anyOf(isNull, TextDecoration.none));
    });

    testWidgets('a link is in the theme colour, announced as a link and '
        'hands its href over on a tap', (tester) async {
      final semantics = tester.ensureSemantics();
      final taps = await pumpRichText(tester, const [
        RichParagraph([
          RichTextRun('See '),
          RichTextRun('the docs', href: 'https://example.com/docs'),
        ]),
      ]);

      final context = tester.element(find.byType(RichTextView));
      expect(
        styleOf(tester, 'the docs').color,
        Theme.of(context).colorScheme.primary,
      );
      expect(styleOf(tester, 'the docs').decoration, TextDecoration.underline);
      expect(
        find.semantics.byPredicate(
          (node) =>
              node.label == 'the docs' &&
              node.flagsCollection.isLink &&
              node.getSemanticsData().hasAction(SemanticsAction.tap),
        ),
        findsOne,
      );

      await tester.tapOnText(find.textRange.ofSubstring('the docs'));
      await tester.pumpAndSettle();

      expect(taps.links, ['https://example.com/docs']);
      semantics.dispose();
    });
  });

  group('pills', () {
    testWidgets('a mention shows the name', (tester) async {
      await pumpRichText(tester, const [
        RichParagraph([
          RichTextRun('Ask '),
          RichMention(username: 'anna', label: 'Anna'),
          RichMention(username: 'ben', label: ''),
        ]),
      ]);

      expect(find.text('Anna'), findsOneWidget);
      expect(find.text('ben'), findsOneWidget);
    });

    testWidgets("a task link shows the local task's title without its "
        'identifier, its project when it is another one, and done tasks '
        'checked and struck through', (tester) async {
      final semantics = tester.ensureSemantics();
      final taps = await pumpRichText(tester, const [
        RichParagraph([
          RichTaskLink(
            taskId: 5,
            href: 'https://tasks.example.org/vikunja/tasks/5',
          ),
          RichTaskLink(
            taskId: 6,
            href: 'https://tasks.example.org/vikunja/tasks/6',
          ),
        ]),
      ]);

      expect(find.text('Pay rent'), findsOneWidget);
      expect(find.text('Home › Paint the fence'), findsOneWidget);
      expect(find.textContaining('WORK-5'), findsNothing);
      expect(find.textContaining('#6'), findsNothing);
      expect(find.byIcon(Icons.done_all), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.text('Home › Paint the fence'))
            .style
            ?.decoration,
        TextDecoration.lineThrough,
      );
      expect(
        find.semantics.byPredicate(
          (node) =>
              node.label == 'Home › Paint the fence, ${en.taskDoneSemantics}' &&
              node.flagsCollection.isLink,
        ),
        findsOne,
      );

      await tester.tap(find.text('Pay rent'));
      expect(taps.tasks, [5]);
      semantics.dispose();
    });

    testWidgets('a task link that is not on this device shows its href and '
        'still opens', (tester) async {
      const href = 'https://tasks.example.org/vikunja/tasks/77';
      final taps = await pumpRichText(tester, const [
        RichParagraph([RichTaskLink(taskId: 77, href: href)]),
      ]);

      expect(find.text(href), findsOneWidget);
      await tester.tap(find.text(href));
      expect(taps.tasks, [77]);
    });

    testWidgets('pills grow with the text at 200 %, not twice as much', (
      tester,
    ) async {
      useAccessibilityExtremes(tester);
      // Short enough for one line: the test font's glyphs are squares.
      data.tasks.all = [...data.tasks.all, sampleTask(id: 8, title: 'Go')];
      await pumpRichText(tester, const [
        RichParagraph([
          RichTextRun('Ask '),
          RichMention(username: 'anna', label: 'Anna'),
          RichTaskLink(
            taskId: 8,
            href: 'https://tasks.example.org/vikunja/tasks/8',
          ),
        ]),
      ]);

      double paintedHeight(Finder finder) {
        final box = tester.renderObject<RenderBox>(finder);
        return box.localToGlobal(box.size.bottomRight(Offset.zero)).dy -
            box.localToGlobal(Offset.zero).dy;
      }

      final paragraph = tester.renderObject<RenderParagraph>(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText && widget.text.toPlainText().contains('Ask'),
        ),
      );
      final lineHeight = paragraph.preferredLineHeight;
      for (final text in ['Anna', 'Go']) {
        expect(
          paintedHeight(find.text(text)),
          moreOrLessEquals(lineHeight, epsilon: 2),
          reason: text,
        );
      }
    });
  });

  group('images', () {
    testWidgets('an attachment image loads at the larger preview size '
        'and opens the original full screen', (tester) async {
      final semantics = tester.ensureSemantics();
      data.attachmentImages
        ..images[(5, 3, AttachmentPreviewSize.extraLarge)] = samplePngImage
        ..images[(5, 3, null)] = samplePngImage;
      await pumpRichText(tester, const [photo]);

      expect(data.attachmentImages.loads, ['5 3 xl']);
      expect(find.byType(Image), findsOneWidget);
      expect(
        find.semantics.byPredicate(
          (node) =>
              node.label == 'The fence' &&
              node.flagsCollection.isImage &&
              node.flagsCollection.isButton,
        ),
        findsOne,
      );

      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();

      expect(find.byType(AttachmentImageViewer), findsOneWidget);
      expect(data.attachmentImages.loads, ['5 3 xl', '5 3 original']);
      expect(find.byType(InteractiveViewer), findsOneWidget);

      await tester.tap(find.byTooltip(en.imageViewerClose));
      await tester.pumpAndSettle();
      expect(find.byType(AttachmentImageViewer), findsNothing);
      semantics.dispose();
    });

    testWidgets('an SVG is never decoded', (tester) async {
      data.attachmentImages.images[(5, 3, AttachmentPreviewSize.extraLarge)] =
          sampleSvgImage;
      await pumpRichText(tester, const [photo]);

      expect(find.byType(Image), findsNothing);
      expect(find.text(en.richTextImageUnsupported), findsOneWidget);
    });

    testWidgets('an image the server has no preview of (2.7.1 and newer) '
        'shows its original, which opens full screen', (tester) async {
      data.attachmentImages
        ..failures[(5, 3, AttachmentPreviewSize.extraLarge)] =
            const DomainError(422, code: 4038)
        ..images[(5, 3, null)] = samplePngImage;
      await pumpRichText(tester, const [photo]);

      expect(data.attachmentImages.loads, ['5 3 xl', '5 3 original']);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text(en.richTextImageFailed), findsNothing);

      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();
      expect(find.byType(AttachmentImageViewer), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('an SVG without a preview is still never decoded', (
      tester,
    ) async {
      data.attachmentImages
        ..failures[(5, 3, AttachmentPreviewSize.extraLarge)] =
            const DomainError(422, code: 4038)
        ..images[(5, 3, null)] = sampleSvgImage;
      await pumpRichText(tester, const [photo]);

      expect(find.byType(Image), findsNothing);
      expect(find.text(en.richTextImageUnsupported), findsOneWidget);
    });

    testWidgets('an image that needs a connection says so and a tap asks '
        'again', (tester) async {
      final semantics = tester.ensureSemantics();
      const key = (5, 3, AttachmentPreviewSize.extraLarge);
      data.attachmentImages.failures[key] = const NetworkFailure(
        NetworkProblem.unreachable,
      );
      await pumpRichText(tester, const [photo]);

      expect(find.byType(Image), findsNothing);
      expect(find.text(en.richTextImageOffline), findsOneWidget);
      expect(
        find.semantics.byPredicate(
          (node) =>
              node.label == en.richTextImageOffline &&
              node.hint == en.retry &&
              node.flagsCollection.isButton,
        ),
        findsOne,
      );

      data.attachmentImages
        ..failures.remove(key)
        ..images[key] = samplePngImage;
      await tester.tap(find.text(en.richTextImageOffline));
      await tester.pumpAndSettle();

      expect(data.attachmentImages.loads, ['5 3 xl', '5 3 xl']);
      expect(find.byType(Image), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('a missing or too large image cannot be asked for again', (
      tester,
    ) async {
      data.attachmentImages
        ..failures[(5, 3, AttachmentPreviewSize.extraLarge)] = const NotFound(
          code: 4011,
        )
        ..failures[(5, 4, AttachmentPreviewSize.extraLarge)] =
            const AttachmentImageTooLarge();
      await pumpRichText(tester, const [
        photo,
        RichImage(
          RichAttachmentImage(AttachmentRef(taskId: 5, attachmentId: 4)),
        ),
      ]);

      expect(find.text(en.richTextImageFailed), findsOneWidget);
      expect(find.text(en.richTextImageUnsupported), findsOneWidget);
      await tester.tap(find.text(en.richTextImageFailed));
      await tester.pumpAndSettle();
      expect(data.attachmentImages.loads, ['5 3 xl', '5 4 xl']);
    });

    testWidgets('an image whose failure is forgotten elsewhere is asked for '
        'again on the next build', (tester) async {
      const key = (5, 3, AttachmentPreviewSize.extraLarge);
      data.attachmentImages.failures[key] = const ServerFailure(502);
      await pumpRichText(tester, const [photo]);
      expect(find.text(en.richTextImageFailed), findsOneWidget);

      data.attachmentImages
        ..failures.remove(key)
        ..images[key] = samplePngImage
        ..forgetFailures();
      tester.element(find.byType(RichTextView)).markNeedsBuild();
      await tester.pumpAndSettle();

      expect(data.attachmentImages.loads, ['5 3 xl', '5 3 xl']);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('the viewer says so when the original does not decode', (
      tester,
    ) async {
      data.attachmentImages
        ..images[(5, 3, AttachmentPreviewSize.extraLarge)] = samplePngImage
        ..images[(5, 3, null)] = AttachmentImage(
          bytes: Uint8List.fromList(List.filled(64, 7)),
          contentType: 'image/png',
        );
      await pumpRichText(tester, const [photo]);
      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AttachmentImageViewer),
          matching: find.text(en.richTextImageUnsupported),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the viewer retries an original that needs a connection', (
      tester,
    ) async {
      data.attachmentImages
        ..images[(5, 3, AttachmentPreviewSize.extraLarge)] = samplePngImage
        ..failures[(5, 3, null)] = const NetworkFailure(
          NetworkProblem.unreachable,
        );
      await pumpRichText(tester, const [photo]);
      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();

      expect(find.text(en.richTextImageOffline), findsOneWidget);
      data.attachmentImages
        ..failures.remove((5, 3, null))
        ..images[(5, 3, null)] = samplePngImage;
      await tester.tap(find.text(en.retry));
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(data.attachmentImages.loads.where((l) => l == '5 3 original'), [
        '5 3 original',
        '5 3 original',
      ]);
    });

    testWidgets('an image elsewhere is never loaded, only named, and opens '
        'in the browser', (tester) async {
      final taps = await pumpRichText(tester, [
        RichImage(
          RichExternalImage(Uri.parse('https://cdn.example.com/a.png')),
        ),
      ]);

      expect(data.attachmentImages.loads, isEmpty);
      expect(find.byType(Image), findsNothing);
      expect(
        find.text(en.richTextImageFrom('cdn.example.com')),
        findsOneWidget,
      );

      await tester.tap(find.text(en.richTextImageFrom('cdn.example.com')));
      expect(taps.links, ['https://cdn.example.com/a.png']);
    });
  });

  testWidgets('200 % text in dark mode lays out', (tester) async {
    useAccessibilityExtremes(tester);
    data.attachmentImages.fallback = samplePngImage;
    await pumpRichText(tester, const [
      RichHeading(2, [RichTextRun('Shopping')]),
      RichTaskList([
        RichTaskItem(
          checked: true,
          blocks: [
            RichParagraph([
              RichTextRun('Milk from the shop at the corner of the street'),
            ]),
          ],
        ),
      ]),
      RichParagraph([
        RichMention(username: 'anna', label: 'Anna'),
        RichTextRun(' see '),
        RichTaskLink(
          taskId: 5,
          href: 'https://tasks.example.org/vikunja/tasks/5',
        ),
      ]),
      RichTable([
        RichTableRow([
          RichTableCell(
            header: true,
            blocks: [
              RichParagraph([RichTextRun('A long header cell')]),
            ],
          ),
        ]),
      ]),
      photo,
    ]);

    expect(tester.takeException(), isNull);
    expect(find.text('Shopping'), findsOneWidget);
  });
}
