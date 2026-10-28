import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/common/presentation/avatar_stack.dart';
import 'package:vikunja_mobile/features/common/presentation/count_badge.dart';
import 'package:vikunja_mobile/features/common/presentation/identifier_text.dart';
import 'package:vikunja_mobile/features/common/presentation/initials_avatar.dart';
import 'package:vikunja_mobile/features/common/presentation/list_section_header.dart';
import 'package:vikunja_mobile/features/common/presentation/search_pill.dart';
import 'package:vikunja_mobile/features/common/presentation/section_card.dart';
import 'package:vikunja_mobile/features/common/presentation/settings_section.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/motd_card.dart';
import 'package:vikunja_mobile/features/upcoming/presentation/timeline_day.dart';

import '../../helpers/pump_app.dart';

void main() {
  Future<ColorScheme> pump(WidgetTester tester, Widget body) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activeAccountIdProvider.overrideWithValue(null)],
        child: MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: Scaffold(body: body),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return Theme.of(tester.element(find.byType(Scaffold))).colorScheme;
  }

  Material materialOf(WidgetTester tester, String text) => tester.widget(
    find.ancestor(of: find.text(text), matching: find.byType(Material)).first,
  );

  group('section card', () {
    testWidgets('puts the rows on one rounded card with dividers between '
        'them, under the header', (tester) async {
      final colors = await pump(
        tester,
        ListView(
          children: const [
            SectionCard(
              title: 'Today',
              trailing: Text('1 of 3 done'),
              children: [Text('One'), Text('Two'), Text('Three')],
            ),
          ],
        ),
      );

      expect(
        tester.widget<ListSectionHeader>(find.byType(ListSectionHeader)).title,
        'Today',
      );
      expect(find.text('1 of 3 done'), findsOneWidget);
      for (final row in ['One', 'Two', 'Three']) {
        expect(materialOf(tester, row).color, colors.surfaceContainerLow);
      }
      BorderRadius radiusOf(String row) =>
          (materialOf(tester, row).shape! as RoundedRectangleBorder)
                  .borderRadius
              as BorderRadius;
      expect(radiusOf('One').topLeft, SectionCardItem.radius);
      expect(radiusOf('One').bottomLeft, Radius.zero);
      expect(radiusOf('Two'), BorderRadius.zero);
      expect(radiusOf('Three').bottomRight, SectionCardItem.radius);
      expect(find.byType(Divider), findsNWidgets(2));
      expect(
        tester.getTopLeft(find.text('One')).dx,
        tester.getTopLeft(find.byType(SectionCardItem).first).dx,
      );
    });

    testWidgets('a single row is rounded at both ends, without a divider', (
      tester,
    ) async {
      await pump(
        tester,
        ListView(
          children: const [
            SectionCard(children: [Text('Only')]),
          ],
        ),
      );

      final shape = materialOf(tester, 'Only').shape! as RoundedRectangleBorder;
      expect(
        shape.borderRadius,
        const BorderRadius.all(SectionCardItem.radius),
      );
      expect(find.byType(Divider), findsNothing);
      expect(find.byType(ListSectionHeader), findsNothing);
    });

    testWidgets('a row that stops or starts being the last keeps its state', (
      tester,
    ) async {
      Widget card(List<String> rows) => ListView(
        children: [
          SectionCard(
            children: [
              for (final row in rows) _StatefulRow(row, key: ValueKey(row)),
            ],
          ),
        ],
      );
      Widget sliverCard(List<String> rows) => CustomScrollView(
        slivers: [
          SliverSectionCard(
            itemCount: rows.length,
            itemBuilder: (context, index) =>
                _StatefulRow(rows[index], key: ValueKey(rows[index])),
          ),
        ],
      );
      for (final build in [card, sliverCard]) {
        await pump(tester, build(['One']));
        final state = tester.state(find.byType(_StatefulRow));

        await pump(tester, build(['One', 'Two']));
        expect(find.byType(Divider), findsOneWidget);
        expect(tester.state(find.byType(_StatefulRow).first), same(state));

        await pump(tester, build(['One']));
        expect(find.byType(Divider), findsNothing);
        expect(tester.state(find.byType(_StatefulRow)), same(state));
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('the sliver variant builds its rows lazily', (tester) async {
      final built = <int>{};
      usePhoneSurface(tester);
      await pump(
        tester,
        CustomScrollView(
          slivers: [
            SliverSectionCard(
              title: 'Later',
              count: 200,
              itemCount: 200,
              itemBuilder: (context, index) {
                built.add(index);
                return SizedBox(height: 56, child: Text('Row $index'));
              },
            ),
          ],
        ),
      );

      expect(
        tester.widget<ListSectionHeader>(find.byType(ListSectionHeader)).count,
        200,
      );
      expect(find.text('200'), findsOneWidget);
      expect(built.length, lessThan(40));
      final first =
          materialOf(tester, 'Row 0').shape! as RoundedRectangleBorder;
      expect(
        (first.borderRadius as BorderRadius).topLeft,
        SectionCardItem.radius,
      );
    });
  });

  testWidgets('a settings section has a divider above, the header and its '
      'tiles', (tester) async {
    final colors = await pump(
      tester,
      ListView(
        children: const [
          SettingsSection(
            title: 'Instance',
            dividerAbove: false,
            children: [ListTile(title: Text('Sync'))],
          ),
          SettingsSection(
            title: 'Appearance',
            children: [ListTile(title: Text('Theme'))],
          ),
        ],
      ),
    );

    expect(find.byType(Divider), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(Divider)).dy,
      lessThan(tester.getTopLeft(find.text('Appearance')).dy),
    );
    expect(
      tester.widget<Text>(find.text('Appearance')).style?.color,
      colors.primary,
    );
    expect(find.text('Theme'), findsOneWidget);
  });

  group('a heading stays a node of its own before a single tappable row, '
      'which reads after it', () {
    Widget tile() => ListTile(title: const Text('Add account'), onTap: () {});
    final sections = <String, (Widget, String)>{
      'settings section': (
        SettingsSection(title: 'Accounts', children: [tile()]),
        'Accounts',
      ),
      'section card': (
        SectionCard(title: 'Accounts', children: [tile()]),
        'Accounts',
      ),
      'Upcoming day': (
        TimelineDay(
          day: DateTime(2026, 10, 10),
          title: 'Accounts',
          today: false,
          rows: [tile()],
        ),
        'Accounts\n1',
      ),
    };
    for (final MapEntry(key: name, value: (section, heading))
        in sections.entries) {
      testWidgets(name, (tester) async {
        await pump(tester, ListView(children: [section]));

        final nodes = _visitedNodes(tester);
        final at = nodes.indexWhere((node) => node.label == heading);
        expect(at, isNonNegative, reason: '$nodes');
        expect(nodes[at].headingLevel, 2);
        expect(nodes[at].hasAction(SemanticsAction.tap), isFalse);
        expect(nodes[at + 1].label, 'Add account');
        expect(nodes[at + 1].hasAction(SemanticsAction.tap), isTrue);
        expect(nodes[at + 1].headingLevel, 0);
      });
    }

    testWidgets("the server's message, which can be selected", (tester) async {
      await pump(
        tester,
        ListView(children: const [MotdCard(message: 'Down tonight')]),
      );

      final nodes = _visitedNodes(tester);
      final heading = nodes.singleWhere((node) => node.headingLevel > 0);
      expect(heading.label, en.motdHeading);
      expect(heading.hasAction(SemanticsAction.tap), isFalse);
      expect(heading.hasAction(SemanticsAction.longPress), isFalse);
      final message = nodes.indexWhere(
        (node) => '${node.label}${node.value}'.contains('Down tonight'),
      );
      expect(nodes.indexOf(heading), lessThan(message));
    });
  });

  testWidgets('a section header is a header with its count', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, const ListSectionHeader(title: 'Overdue', count: 3));

    expect(
      tester.getSemantics(find.text('Overdue')),
      isSemantics(isHeader: true, label: 'Overdue\n3'),
    );
    semantics.dispose();
  });

  testWidgets('a section header takes another title colour, and a long '
      'trailing text wraps in large text instead of crowding the title', (
    tester,
  ) async {
    usePhoneSurface(tester, logicalSize: const Size(320, 640));
    useAccessibilityExtremes(tester);
    final colors = await pump(
      tester,
      const Column(
        children: [
          ListSectionHeader(
            title: 'Overdue',
            count: 3,
            color: Color(0xFFB00020),
          ),
          ListSectionHeader(
            title: 'Notifications',
            trailing: Text('Only on this device, not your account'),
          ),
        ],
      ),
    );

    expect(
      tester.widget<Text>(find.text('Overdue')).style?.color,
      const Color(0xFFB00020),
    );
    expect(
      tester.widget<Text>(find.text('Notifications')).style?.color,
      colors.primary,
    );
    expect(
      tester.getSize(find.text('Only on this device, not your account')).width,
      lessThanOrEqualTo(320 * 0.4),
    );
    expect(tester.takeException(), isNull);
  });

  group('count badge', () {
    testWidgets('shows the count and the limit, in the error colours once '
        'over it', (tester) async {
      final colors = await pump(
        tester,
        const Column(
          children: [
            CountBadge(count: 3),
            CountBadge(count: 3, limit: 5),
            CountBadge(count: 6, limit: 5),
            CountBadge(count: 5, limit: 5, alert: true),
          ],
        ),
      );

      Color? fillOf(String text) {
        final badge = tester.widget<DecoratedBox>(
          find
              .ancestor(
                of: find.text(text),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        return (badge.decoration as ShapeDecoration).color;
      }

      expect(fillOf('3'), colors.secondaryContainer);
      expect(fillOf('3/5'), colors.secondaryContainer);
      expect(fillOf('6/5'), colors.error);
      expect(fillOf('5/5'), colors.error);
    });

    testWidgets('reads its label to screen readers', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(
        tester,
        const CountBadge(count: 2, limit: 4, semanticsLabel: '2 of 4 tasks'),
      );

      expect(find.bySemanticsLabel('2 of 4 tasks'), findsOneWidget);
      semantics.dispose();
    });
  });

  testWidgets('the search pill opens on a tap and keeps its trailing '
      'button apart', (tester) async {
    final semantics = tester.ensureSemantics();
    var opened = 0;
    var avatar = 0;
    await pump(
      tester,
      SearchPill(
        hint: 'Search tasks',
        onTap: () => opened++,
        trailing: IconButton(
          tooltip: 'Accounts',
          onPressed: () => avatar++,
          icon: const Icon(Icons.person),
        ),
      ),
    );

    expect(tester.getSize(find.byType(SearchPill)).height, 56);
    expect(
      tester.getSemantics(find.text('Search tasks')),
      isSemantics(isButton: true, label: 'Search tasks', hasTapAction: true),
    );
    await tester.tap(find.text('Search tasks'));
    await tester.tap(find.byTooltip('Accounts'));
    expect((opened, avatar), (1, 1));
    semantics.dispose();
  });

  testWidgets('an identifier is small, muted and monospaced', (tester) async {
    final colors = await pump(tester, const IdentifierText('WORK-12'));

    final style = tester.widget<Text>(find.text('WORK-12')).style!;
    expect(style.fontFamily, 'monospace');
    expect(style.fontSize, 12);
    expect(style.color, colors.onSurfaceVariant);
  });

  group('avatar stack', () {
    const people = [
      User(id: 1, username: 'anna', name: 'Anna'),
      User(id: 2, username: 'ben'),
      User(id: 3, username: 'cleo', name: 'Cleo'),
      User(id: 4, username: 'dan', name: 'Dan'),
      User(id: 5, username: 'eve', name: 'Eve'),
    ];

    testWidgets('overlaps up to three avatars and counts the rest', (
      tester,
    ) async {
      await pump(tester, const Center(child: AvatarStack(users: people)));

      expect(find.byType(InitialsAvatar), findsNWidgets(3));
      expect(find.text(en.taskMoreAssignees(2)), findsOneWidget);
      expect(
        tester.getSize(find.byType(AvatarStack)).width,
        AvatarStack.widthOf(people.length),
      );
      expect(AvatarStack.widthOf(1), 24);
      expect(AvatarStack.widthOf(2), 42);
      expect(AvatarStack.widthOf(5), 78);
      expect(AvatarStack.widthOf(0), 0);
    });
  });
}

class _StatefulRow extends StatefulWidget {
  const new(this.label, {super.key});

  final String label;

  @override
  State<_StatefulRow> createState() => _StatefulRowState();
}

class _StatefulRowState extends State<_StatefulRow> {
  @override
  Widget build(BuildContext context) => Text(widget.label);
}

/// The nodes with a label or a value that a screen reader visits, in its
/// order.
List<SemanticsData> _visitedNodes(WidgetTester tester) {
  final nodes = <SemanticsData>[];
  void visit(SemanticsNode node) {
    if (node.isMergedIntoParent) return;
    final data = node.getSemanticsData();
    if (data.label.isNotEmpty || data.value.isNotEmpty) nodes.add(data);
    node
        .debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)
        .forEach(visit);
  }

  for (final view in tester.binding.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) visit(root);
  }
  return nodes;
}
