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

  group('a round trip that can recover', () {
    late Completer<String> answer;
    late List<Completer<String>> recovers;

    Future<String> roundTrip() => excursions.roundTrip(
      () => answer.future,
      recover: () {
        recovers.add(Completer());
        return recovers.last.future;
      },
    );

    void setUpRecovery(WidgetTester tester) {
      setUpExcursions(tester);
      answer = Completer();
      recovers = [];
    }

    testWidgets('answers with what it recovers after an abandon', (
      tester,
    ) async {
      setUpRecovery(tester);
      final result = roundTrip();

      excursions.abandon();
      expect(recovers, hasLength(1));
      recovers.single.complete('recovered');

      expect(await result, 'recovered');
      expect(excursions.active, isFalse);
      expect(ended, isEmpty);
    });

    testWidgets('recovers nothing without an abandon', (tester) async {
      setUpRecovery(tester);
      final result = roundTrip();
      await tester.pump(const Duration(minutes: 1));

      answer.complete('picked');

      expect(await result, 'picked');
      expect(recovers, isEmpty);
    });

    testWidgets('keeps an answer that came first and recovers nothing on a '
        'later abandon', (tester) async {
      setUpRecovery(tester);
      final result = roundTrip();
      String? answered;
      unawaited(result.then((value) => answered = value));

      step(tester, _away);
      answer.complete('picked');
      await tester.pump();
      excursions.abandon();
      step(tester, _back);
      await tester.pump();

      expect(answered, 'picked');
      expect(recovers, isEmpty);
    });

    testWidgets('ignores a late answer', (tester) async {
      setUpRecovery(tester);
      final result = roundTrip();

      excursions.abandon();
      recovers.single.complete('recovered');
      expect(await result, 'recovered');

      answer.complete('late');
      await tester.pump();
      expect(await result, 'recovered');
    });

    testWidgets('ignores a late failure', (tester) async {
      setUpRecovery(tester);
      final result = roundTrip();

      excursions.abandon();
      recovers.single.complete('recovered');
      expect(await result, 'recovered');

      answer.completeError(StateError('detached'));
      await tester.pump();
      expect(await result, 'recovered');
    });

    testWidgets('keeps an answer that comes while it recovers, and ignores a '
        'failed recovery after it', (tester) async {
      setUpRecovery(tester);
      final result = roundTrip();

      excursions.abandon();
      answer.complete('picked');
      expect(await result, 'picked');

      recovers.single.completeError(StateError('no activity'));
      await tester.pump();
      expect(await result, 'picked');
    });

    testWidgets('stops listening for abandons once it is answered', (
      tester,
    ) async {
      setUpRecovery(tester);
      final result = roundTrip();
      expect(excursions.listensForAbandons, isTrue);

      answer.complete('picked');

      expect(await result, 'picked');
      expect(excursions.listensForAbandons, isFalse);
    });

    testWidgets('recovers nothing on an abandon between the answer and the '
        'end of listening', (tester) async {
      setUpRecovery(tester);
      final result = roundTrip();

      answer.complete('picked');
      await answer.future;
      expect(excursions.listensForAbandons, isTrue);
      excursions.abandon();

      expect(await result, 'picked');
      expect(recovers, isEmpty);
    });

    testWidgets('recovers once however many abandons come', (tester) async {
      setUpRecovery(tester);
      final result = roundTrip();

      excursions
        ..abandon()
        ..abandon();
      recovers.single.complete('recovered');
      await result;
      excursions.abandon();

      expect(recovers, hasLength(1));
    });

    testWidgets('passes a failed recovery on', (tester) async {
      setUpRecovery(tester);
      final result = roundTrip();

      excursions.abandon();
      recovers.single.completeError(StateError('no activity'));

      await expectLater(result, throwsStateError);
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

    testWidgets('a relaunch under its dialog is no return', (tester) async {
      setUpExcursions(tester);

      await excursions.launchAway(() async => true, opened: (open) => open);
      step(tester, const [AppLifecycleState.inactive]);
      step(tester, const [
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.detached,
        AppLifecycleState.resumed,
        AppLifecycleState.inactive,
      ]);
      await tester.pump();
      expect(excursions.active, isTrue);

      step(tester, const [AppLifecycleState.resumed]);
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
