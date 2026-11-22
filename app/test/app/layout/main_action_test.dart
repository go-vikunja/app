import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/layout/large_text.dart';
import 'package:vikunja_mobile/app/layout/main_action.dart';

/// Android 14's scaling at its 150 % step: 14 sp become 22 dp, 16 sp 23.
final class _Android14At150 extends TextScaler {
  const new();

  @override
  double scale(double fontSize) => switch (fontSize) {
    <= 14 => fontSize * 22 / 14,
    <= 18 => 22 + (fontSize - 14) / 2,
    _ => fontSize * 1.3,
  };

  @override
  double get textScaleFactor => 1.5;
}

void main() {
  final pressed = <String>[];

  MainAction action(String name) => MainAction(
    icon: Icons.add,
    label: name,
    onPressed: () => pressed.add(name),
  );

  setUp(pressed.clear);

  group('large text', () {
    for (final (name, scaler, large) in [
      ('1.3', const TextScaler.linear(1.3), false),
      ('1.5', const TextScaler.linear(1.5), true),
      ("Android 14's 150 %", const _Android14At150(), true),
      ('2', const TextScaler.linear(2), true),
    ]) {
      testWidgets('at $name: $large', (tester) async {
        late bool found;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: scaler),
            child: Builder(
              builder: (context) {
                found = largeTextOf(context);
                return const SizedBox();
              },
            ),
          ),
        );
        expect(found, large);
      });
    }
  });

  group("a screen's floating button", () {
    Future<void> pumpButton(WidgetTester tester, TextScaler scaler) =>
        tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: scaler),
              child: child!,
            ),
            home: Scaffold(
              floatingActionButton: MainActionButton(action: action('New')),
            ),
          ),
        );

    testWidgets('is extended with its label', (tester) async {
      await pumpButton(tester, const TextScaler.linear(1.3));

      expect(find.text('New'), findsOneWidget);
      expect(find.byTooltip('New'), findsNothing);
    });

    testWidgets('from 1.5 times the text only its icon, its label the '
        'tooltip', (tester) async {
      await pumpButton(tester, const TextScaler.linear(2));

      expect(find.text('New'), findsNothing);
      expect(
        tester.getSize(find.byType(FloatingActionButton)),
        const Size.square(56),
      );
      await tester.tap(find.byTooltip('New'));
      expect(pressed, ['New']);
    });
  });

  group('the rail', () {
    late RailMainActions actions;

    setUp(() => actions = RailMainActions());
    tearDown(() => actions.dispose());

    /// A rail button beside [screen], with the actions offered while
    /// [rail].
    Widget shell(Widget screen, {bool rail = true}) => MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            RailMainActionButton(actions: actions),
            Expanded(
              child: RailMainActions.scope(
                actions: rail ? actions : null,
                child: screen,
              ),
            ),
          ],
        ),
      ),
    );

    Widget screen(String name, {bool hasAction = true}) => Builder(
      builder: (context) {
        final offered = hasAction ? action(name) : null;
        return MainActionClaim(
          action: offered,
          child: Scaffold(
            body: Text(name),
            floatingActionButton: MainActionButton.unlessBesideRail(
              context,
              offered,
            ),
          ),
        );
      },
    );

    Finder railButton() => find.descendant(
      of: find.byType(RailMainActionButton),
      matching: find.byType(FloatingActionButton),
    );

    testWidgets('offers the action of the screen in front, which shows no '
        'floating button of its own', (tester) async {
      await tester.pumpWidget(shell(screen('Overview')));
      await tester.pump();

      expect(railButton(), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      await tester.tap(railButton());
      expect(pressed, ['Overview']);
    });

    testWidgets('without the rail, the screen keeps its button', (
      tester,
    ) async {
      await tester.pumpWidget(shell(screen('Overview'), rail: false));
      await tester.pump();

      expect(railButton(), findsNothing);
      expect(
        find.widgetWithText(FloatingActionButton, 'Overview'),
        findsOneWidget,
      );
      final slot = tester.getSize(find.byType(RailMainActionButton));
      expect(slot, const Size.square(RailMainActionButton.size));
    });

    testWidgets('a hidden tab offers nothing, the shown one its own', (
      tester,
    ) async {
      Widget tabs(int shown) => Stack(
        children: [
          for (final (index, name) in ['Overview', 'Account'].indexed)
            Offstage(
              offstage: index != shown,
              child: TickerMode(
                enabled: index == shown,
                child: screen(name, hasAction: name != 'Account'),
              ),
            ),
        ],
      );

      await tester.pumpWidget(shell(tabs(0)));
      await tester.pump();
      expect(railButton(), findsOneWidget);

      await tester.pumpWidget(shell(tabs(1)));
      await tester.pump();
      expect(railButton(), findsNothing);
      expect(
        tester.getSize(find.byType(RailMainActionButton)),
        const Size.square(RailMainActionButton.size),
        reason: 'the destinations below stay in place',
      );

      await tester.pumpWidget(shell(tabs(0)));
      await tester.pump();
      await tester.tap(railButton());
      expect(pressed, ['Overview']);
    });

    testWidgets('a page pushed over the screen offers its own or none; '
        'back, the screen offers its own again', (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        shell(
          Navigator(
            key: navigator,
            onGenerateRoute: (_) =>
                MaterialPageRoute<void>(builder: (_) => screen('List')),
          ),
        ),
      );
      await tester.pump();

      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => screen('Project')),
      );
      await tester.pumpAndSettle();
      await tester.tap(railButton());
      expect(pressed, ['Project']);

      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => screen('Details', hasAction: false),
        ),
      );
      await tester.pumpAndSettle();
      expect(railButton(), findsNothing);

      navigator.currentState!
        ..pop()
        ..pop();
      await tester.pumpAndSettle();
      await tester.tap(railButton());
      expect(pressed, ['Project', 'List']);
    });

    testWidgets('a menu or a sheet over the screen keeps its action in the '
        'rail', (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        shell(
          Navigator(
            key: navigator,
            onGenerateRoute: (_) =>
                MaterialPageRoute<void>(builder: (_) => screen('Upcoming')),
          ),
        ),
      );
      await tester.pump();
      final context = navigator.currentContext!;

      showMenu<void>(
        context: context,
        position: RelativeRect.fill,
        items: const [PopupMenuItem(child: Text('Refresh'))],
      );
      await tester.pumpAndSettle();
      expect(railButton(), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();

      showModalBottomSheet<void>(
        context: context,
        builder: (_) => const Text('Sheet'),
      );
      await tester.pumpAndSettle();
      expect(railButton(), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();

      await tester.tap(railButton());
      expect(pressed, ['Upcoming']);
    });
  });
}
