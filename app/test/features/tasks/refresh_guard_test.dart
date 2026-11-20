import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/refresh_guard.dart';

void main() {
  late int refreshes;
  late RefreshGuard guard;

  setUp(() {
    refreshes = 0;
    guard = RefreshGuard(() async => refreshes++);
  });

  test('a refresh asked for during a write runs once it is done', () async {
    final write = Completer<int>();
    final writing = guard.writing(() => write.future);
    expect(guard.hasWrites, isTrue);

    guard
      ..markDue()
      ..refreshIfDue();
    expect(refreshes, 0);

    write.complete(3);
    expect(await writing, 3);
    expect(guard.hasWrites, isFalse);
    expect(refreshes, 1);
  });

  test(
    'a write drops the refresh under way and reads again after it',
    () async {
      guard.refreshing = ++guard.generation;
      final write = Completer<void>();
      final writing = guard.writing(() => write.future);

      expect(guard.refreshing, isNull);
      expect(guard.generation, 2);
      expect(refreshes, 0);

      write.complete();
      await writing;
      expect(refreshes, 1);
    },
  );

  test('without a write, a dropped refresh is read again at once', () {
    guard.refreshing = ++guard.generation;

    guard.drop();

    expect(guard.refreshing, isNull);
    expect(guard.generation, 2);
    expect(refreshes, 1);
  });

  test('a refresh a newer read overtook is not dropped', () {
    guard.refreshing = ++guard.generation;
    guard.generation++;

    guard.drop();

    expect(guard.refreshing, 1);
    expect(guard.generation, 2);
    expect(refreshes, 0);
  });

  test('a failed write still lets the refresh run', () async {
    guard.markDue();
    await expectLater(
      guard.writing<void>(() async => throw StateError('refused')),
      throwsStateError,
    );

    expect(guard.hasWrites, isFalse);
    expect(refreshes, 1);
  });

  test('nothing runs once disposed', () {
    guard
      ..refreshing = ++guard.generation
      ..dispose()
      ..drop()
      ..markDue()
      ..refreshIfDue();

    expect(guard.disposed, isTrue);
    expect(refreshes, 0);
  });
}
