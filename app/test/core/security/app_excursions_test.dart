import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/security/app_excursions.dart';

void main() {
  var now = DateTime.utc(2026, 10, 27, 9);
  late AppExcursions excursions;
  late List<DateTime> ended;

  setUp(() {
    now = DateTime.utc(2026, 10, 27, 9);
    excursions = AppExcursions(now: () => now);
    ended = [];
    excursions.ended.listen(ended.add);
    addTearDown(excursions.dispose);
  });

  test('is active while the action runs and returns its result', () async {
    final picker = Completer<String>();

    final result = excursions.run(() => picker.future);
    expect(excursions.active, isTrue);
    expect(excursions.startedAt, now);
    picker.complete('photo.jpg');

    expect(await result, 'photo.jpg');
    expect(excursions.active, isFalse);
    expect(excursions.startedAt, isNull);
    expect(ended, [DateTime.utc(2026, 10, 27, 9)]);
  });

  test('nested and overlapping ones count until the last ends, from the '
      'first start', () async {
    final first = Completer<void>();
    final second = Completer<void>();
    final start = now;

    final outer = excursions.run(() async {
      await first.future;
    });
    now = now.add(const Duration(seconds: 30));
    final overlapping = excursions.run(() => second.future);
    first.complete();
    await outer;

    expect(excursions.active, isTrue);
    expect(excursions.startedAt, start);
    expect(ended, isEmpty);

    second.complete();
    await overlapping;

    expect(excursions.active, isFalse);
    expect(ended, [start]);
  });

  test('ends when the action fails, and passes the error on', () async {
    await expectLater(
      excursions.run<void>(() async => throw StateError('no camera')),
      throwsA(isA<StateError>()),
    );

    expect(excursions.active, isFalse);
    expect(ended, hasLength(1));
  });
}
