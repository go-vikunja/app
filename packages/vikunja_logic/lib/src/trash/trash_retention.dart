/// How long the server keeps a deleted task or project in its trash. It is
/// fixed in Vikunja and not reported by the server.
const trashRetention = Duration(days: 30);

/// Whole days until the server deletes an item moved to the trash at
/// [deletedAt] for good, rounded up, never below 0 and never above
/// [trashRetention]'s 30, also when the device's clock is behind the
/// server's. 0 means today: the server purges once an hour, so the item
/// may stay up to an hour longer.
int trashDaysLeft(DateTime deletedAt, {required DateTime now}) {
  final left = deletedAt.add(trashRetention).difference(now);
  if (left <= Duration.zero) return 0;
  const day = Duration.microsecondsPerDay;
  final days = (left.inMicroseconds + day - 1) ~/ day;
  return days > trashRetention.inDays ? trashRetention.inDays : days;
}
