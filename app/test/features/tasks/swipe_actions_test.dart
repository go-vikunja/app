import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/features/tasks/presentation/swipe_actions.dart';

void main() {
  late List<String> triggered;

  setUp(() => triggered = []);

  SwipeAction action(String name) => SwipeAction(
    icon: Icons.check,
    label: name,
    color: Colors.green,
    onColor: Colors.white,
    onTriggered: () => triggered.add(name),
  );

  Future<void> pumpRow(
    WidgetTester tester, {
    bool start = true,
    bool end = true,
    TextDirection direction = TextDirection.ltr,
    GestureDragEndCallback? outerDragEnd,
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: GestureDetector(
              onHorizontalDragEnd: outerDragEnd,
              child: SwipeActions(
                startAction: start ? action('start') : null,
                endAction: end ? action('end') : null,
                child: const SizedBox(
                  height: 56,
                  child: Center(child: Text('Row')),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Offset rowOffset(WidgetTester tester) => tester.getTopLeft(find.text('Row'));

  testWidgets('a swipe toward the end past the threshold runs the start '
      'edge action once, and the row slides back', (tester) async {
    await pumpRow(tester);
    final rest = rowOffset(tester);

    await tester.drag(find.text('Row'), const Offset(200, 0));
    await tester.pumpAndSettle();

    expect(triggered, ['start']);
    expect(rowOffset(tester), rest);
  });

  testWidgets('a swipe toward the start runs the end edge action', (
    tester,
  ) async {
    await pumpRow(tester);

    await tester.drag(find.text('Row'), const Offset(-200, 0));
    await tester.pumpAndSettle();

    expect(triggered, ['end']);
  });

  testWidgets('a short slow swipe runs nothing', (tester) async {
    await pumpRow(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Row')),
    );
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(triggered, isEmpty);
  });

  testWidgets('a fling past a quarter of the width runs it before the '
      'threshold', (tester) async {
    await pumpRow(tester);

    await tester.fling(find.text('Row'), const Offset(110, 0), 1500);
    await tester.pumpAndSettle();

    expect(triggered, ['start']);
  });

  testWidgets('the strip shows the action name while the row is out', (
    tester,
  ) async {
    await pumpRow(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Row')),
    );
    await gesture.moveBy(const Offset(40, 0));
    await gesture.moveBy(const Offset(160, 0));
    await tester.pump();
    expect(find.text('start'), findsOneWidget);
    expect(find.text('end'), findsNothing);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('start'), findsNothing);
  });

  testWidgets('right to left, the start edge is on the right', (tester) async {
    await pumpRow(tester, direction: TextDirection.rtl);

    await tester.drag(find.text('Row'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Row'), const Offset(200, 0));
    await tester.pumpAndSettle();

    expect(triggered, ['start', 'end']);
  });

  testWidgets('without an action that way the row stays and nothing runs', (
    tester,
  ) async {
    await pumpRow(tester, end: false);
    final rest = rowOffset(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Row')),
    );
    await gesture.moveBy(const Offset(-40, 0));
    await gesture.moveBy(const Offset(-160, 0));
    await tester.pump();
    expect(rowOffset(tester), rest);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(triggered, isEmpty);
  });

  testWidgets('without any action the row leaves horizontal drags to what '
      'is around it', (tester) async {
    var outer = 0;
    await pumpRow(
      tester,
      start: false,
      end: false,
      outerDragEnd: (_) => outer++,
    );

    await tester.drag(find.text('Row'), const Offset(200, 0));
    await tester.pumpAndSettle();

    expect(outer, 1);
    expect(triggered, isEmpty);
  });

  testWidgets('crossing the threshold ticks, both ways', (tester) async {
    final haptics = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments);
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
    await pumpRow(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Row')),
    );
    await gesture.moveBy(const Offset(40, 0));
    await gesture.moveBy(const Offset(160, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-150, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(haptics, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
    ]);
    expect(triggered, isEmpty);
  });
}
