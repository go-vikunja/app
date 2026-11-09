import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

void main() {
  final deletedAt = DateTime.utc(2026, 11, 9, 9, 32, 31);

  int daysLeftAfter(Duration elapsed) =>
      trashDaysLeft(deletedAt, now: deletedAt.add(elapsed));

  test('the server keeps an item for 30 days', () {
    expect(trashRetention, const Duration(days: 30));
  });

  test('just deleted: 30 days', () {
    expect(daysLeftAfter(Duration.zero), 30);
  });

  test('29 days and an hour left: 30', () {
    expect(
      daysLeftAfter(trashRetention - const Duration(days: 29, hours: 1)),
      30,
    );
  });

  test('a part of a day counts as a whole one', () {
    expect(daysLeftAfter(const Duration(seconds: 1)), 30);
    expect(daysLeftAfter(const Duration(days: 1)), 29);
    expect(daysLeftAfter(const Duration(days: 1, seconds: 1)), 29);
  });

  test('one second before the end: 1', () {
    expect(daysLeftAfter(trashRetention - const Duration(seconds: 1)), 1);
  });

  test('exactly 30 days later: 0, deleted for good today', () {
    expect(daysLeftAfter(trashRetention), 0);
  });

  test('later, while the hourly purge has not run yet: 0', () {
    expect(daysLeftAfter(trashRetention + const Duration(minutes: 59)), 0);
    expect(daysLeftAfter(const Duration(days: 45)), 0);
  });

  test('a deletion after now, a device clock behind the server: 30', () {
    expect(daysLeftAfter(const Duration(seconds: -1)), 30);
    expect(daysLeftAfter(const Duration(days: -3, hours: -2)), 30);
  });

  test('UTC and local times give the same days', () {
    final local = deletedAt.toLocal();
    final now = deletedAt.add(const Duration(days: 12, hours: 3));

    expect(trashDaysLeft(local, now: now), 18);
    expect(trashDaysLeft(deletedAt, now: now.toLocal()), 18);
    expect(trashDaysLeft(local, now: now.toLocal()), 18);
    expect(trashDaysLeft(deletedAt, now: now), 18);
  });
}
