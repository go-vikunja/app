import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/features/common/presentation/latest_read.dart';

final _log = Logger('LatestReadTest');

class _Probe extends StatefulWidget {
  const new();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with LatestReads {
  final slot = LatestRead<int?>();

  /// What the callbacks saw of [slot] when they ran.
  final calls = <String>[];

  Future<void> read(Future<int?> answer) => readLatest(
    slot,
    () => answer,
    log: _log,
    what: 'the probe',
    onValue: (value) => calls.add(
      'value $value: ${slot.value} ${slot.failure} ${slot.loading}',
    ),
    onFailure: (error) => calls.add(
      'failure $error: ${slot.value} ${slot.failure} ${slot.loading}',
    ),
  );

  @override
  Widget build(BuildContext context) => Text(
    [
      if (slot.hasValue) 'value ${slot.value}' else 'no value',
      if (slot.failure case final failure?) 'failure $failure',
      if (slot.loading) 'loading',
    ].join(', '),
    textDirection: TextDirection.ltr,
  );
}

void main() {
  late List<String> logs;

  setUp(() {
    logs = [];
    final previousLevel = Logger.root.level;
    Logger.root.level = Level.ALL;
    final subscription = Logger.root.onRecord.listen(
      (record) => logs.add('${record.level.name} ${record.message}'),
    );
    addTearDown(() {
      Logger.root.level = previousLevel;
      return subscription.cancel();
    });
  });

  Future<_ProbeState> pumpProbe(WidgetTester tester) async {
    await tester.pumpWidget(const _Probe());
    return tester.state<_ProbeState>(find.byType(_Probe));
  }

  String shown(WidgetTester tester) =>
      tester.widget<Text>(find.byType(Text)).data!;

  testWidgets('before any read there is no value and nothing loads', (
    tester,
  ) async {
    await pumpProbe(tester);

    expect(shown(tester), 'no value');
  });

  testWidgets('a read loads until it answers, then shows its value', (
    tester,
  ) async {
    final probe = await pumpProbe(tester);
    final answer = Completer<int?>();

    unawaited(probe.read(answer.future));
    await tester.pump();
    expect(shown(tester), 'no value, loading');

    answer.complete(1);
    await tester.pumpAndSettle();
    expect(shown(tester), 'value 1');
  });

  testWidgets('of two reads, the later one wins although the earlier one '
      'answers last', (tester) async {
    final probe = await pumpProbe(tester);
    final first = Completer<int?>();
    final second = Completer<int?>();

    unawaited(probe.read(first.future));
    unawaited(probe.read(second.future));
    second.complete(2);
    await tester.pumpAndSettle();
    expect(shown(tester), 'value 2');

    first.complete(1);
    await tester.pumpAndSettle();
    expect(shown(tester), 'value 2');
    expect(probe.calls, ['value 2: 2 null true']);
  });

  testWidgets('loading lasts until the latest read ends, not the earlier '
      'one', (tester) async {
    final probe = await pumpProbe(tester);
    final first = Completer<int?>();
    final second = Completer<int?>();

    unawaited(probe.read(first.future));
    unawaited(probe.read(second.future));
    first.complete(1);
    await tester.pumpAndSettle();
    expect(shown(tester), 'no value, loading');

    second.complete(2);
    await tester.pumpAndSettle();
    expect(shown(tester), 'value 2');
  });

  testWidgets('a failure keeps the last value; the next answer clears it', (
    tester,
  ) async {
    final probe = await pumpProbe(tester);

    await probe.read(Future.value(1));
    await probe.read(Future.error(StateError('down')));
    await tester.pump();
    expect(shown(tester), 'value 1, failure Bad state: down');
    expect(probe.calls.last, 'failure Bad state: down: 1 Bad state: down true');

    await probe.read(Future.value(3));
    await tester.pump();
    expect(shown(tester), 'value 3');
  });

  testWidgets("an earlier read's failure is dropped, but logged", (
    tester,
  ) async {
    final probe = await pumpProbe(tester);
    final first = Completer<int?>();
    final second = Completer<int?>();

    unawaited(probe.read(first.future));
    unawaited(probe.read(second.future));
    second.complete(2);
    first.completeError(StateError('late'));
    await tester.pump();

    expect(shown(tester), 'value 2');
    expect(probe.calls, ['value 2: 2 null true']);
    expect(logs, ['INFO Reading the probe failed: StateError']);
  });

  testWidgets('a null answer is a value', (tester) async {
    final probe = await pumpProbe(tester);

    await probe.read(Future.value());
    await tester.pump();

    expect(probe.slot.hasValue, isTrue);
    expect(shown(tester), 'value null');
  });

  testWidgets('a change made on the page is a value; forget drops it', (
    tester,
  ) async {
    final probe = await pumpProbe(tester);

    probe.slot.value = 5;
    expect(probe.slot.hasValue, isTrue);
    expect(probe.slot.value, 5);

    probe.slot.forget();
    expect(probe.slot.hasValue, isFalse);
    expect(probe.slot.value, isNull);
  });

  for (final fails in [false, true]) {
    testWidgets('after the page ended, ${fails ? 'a failure' : 'an answer'} '
        'changes nothing', (tester) async {
      final probe = await pumpProbe(tester);
      final answer = Completer<int?>();
      final read = probe.read(answer.future);

      await tester.pumpWidget(const SizedBox());
      if (fails) {
        answer.completeError(StateError('gone'));
      } else {
        answer.complete(1);
      }
      await read;

      expect(probe.slot.hasValue, isFalse);
      expect(probe.slot.failure, isNull);
      expect(probe.slot.loading, isTrue);
      expect(probe.calls, isEmpty);
    });
  }
}
