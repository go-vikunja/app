import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/platform/app_round_trips.dart';
import 'package:vikunja_mobile/core/security/app_excursions.dart';

const List<AppLifecycleState> _away = [
  AppLifecycleState.inactive,
  AppLifecycleState.hidden,
  AppLifecycleState.paused,
];
const List<AppLifecycleState> _back = [
  AppLifecycleState.hidden,
  AppLifecycleState.inactive,
  AppLifecycleState.resumed,
];

void main() {
  late AppExcursions excursions;
  late List<DateTime> ended;

  void step(WidgetTester tester, List<AppLifecycleState> states) {
    states.forEach(tester.binding.handleAppLifecycleStateChanged);
  }

  void setUpExcursions(WidgetTester tester) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    excursions = AppExcursions(now: () => DateTime.utc(2026, 10, 27, 9));
    ended = [];
    final subscription = excursions.ended.listen(ended.add);
    addTearDown(() async {
      await subscription.cancel();
      excursions.dispose();
    });
  }

  group('a round trip', () {
    testWidgets('lasts until the resume when the answer comes while the app '
        'is still out of sight', (tester) async {
      setUpExcursions(tester);
      final answer = Completer<String>();
      final result = excursions.roundTrip(() => answer.future);
      expect(excursions.active, isTrue);

      step(tester, _away);
      answer.complete('picked');
      await tester.pump();
      expect(excursions.active, isTrue);

      step(tester, _back.take(2).toList());
      await tester.pump();
      expect(excursions.active, isTrue);

      step(tester, _back.skip(2).toList());
      expect(await result, 'picked');
      expect(excursions.active, isFalse);
      expect(ended, hasLength(1));
    });

    testWidgets('ends with an answer in the foreground', (tester) async {
      setUpExcursions(tester);

      expect(await excursions.roundTrip(() async => 3), 3);
      expect(excursions.active, isFalse);
      expect(ended, hasLength(1));
    });

    testWidgets('that fails out of sight ends at the resume and passes the '
        'error on', (tester) async {
      setUpExcursions(tester);
      final answer = Completer<void>();
      final result = excursions.roundTrip(() => answer.future);
      Object? failure;
      unawaited(result.catchError((Object error) => failure = error));

      step(tester, _away);
      answer.completeError(StateError('picker failed'));
      await tester.pump();
      expect(excursions.active, isTrue);

      step(tester, _back);
      await tester.pump();
      expect(failure, isA<StateError>());
      expect(excursions.active, isFalse);
    });
  });

  group('a launch away', () {
    testWidgets('answers at once and lasts until the app has left and is '
        'back', (tester) async {
      setUpExcursions(tester);

      expect(
        await excursions.launchAway(() async => true, opened: (open) => open),
        isTrue,
      );
      expect(excursions.active, isTrue);

      step(tester, _away);
      await tester.pump();
      expect(excursions.active, isTrue);

      step(tester, _back);
      await tester.pump();
      expect(excursions.active, isFalse);
      expect(ended, hasLength(1));
    });

    testWidgets('a dialog over the app counts as leaving', (tester) async {
      setUpExcursions(tester);

      await excursions.launchAway(() async => true, opened: (open) => open);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(excursions.active, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(excursions.active, isFalse);
    });

    testWidgets('waits for the return also when the app left before the '
        'launch answered', (tester) async {
      setUpExcursions(tester);
      final answer = Completer<bool>();
      final result = excursions.launchAway(
        () => answer.future,
        opened: (open) => open,
      );

      step(tester, _away);
      answer.complete(true);
      expect(await result, isTrue);
      expect(excursions.active, isTrue);

      step(tester, _back);
      await tester.pump();
      expect(excursions.active, isFalse);
    });

    testWidgets('that opened nothing ends at once', (tester) async {
      setUpExcursions(tester);

      expect(
        await excursions.launchAway(() async => false, opened: (open) => open),
        isFalse,
      );
      await tester.pump();
      expect(excursions.active, isFalse);
      expect(ended, hasLength(1));
    });

    testWidgets('that fails passes the error on and ends', (tester) async {
      setUpExcursions(tester);

      await expectLater(
        excursions.launchAway<bool>(
          () async => throw StateError('no activity'),
          opened: (open) => open,
        ),
        throwsStateError,
      );
      await tester.pump();
      expect(excursions.active, isFalse);
    });
  });
}
