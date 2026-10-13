import 'package:flutter/foundation.dart';
import 'package:vikunja_mobile/core/activity/activity_item.dart';

enum ActivityDay { today, yesterday, earlier }

@immutable
final class ActivitySection {
  const new(this.day, this.items);

  final ActivityDay day;
  final List<ActivityItem> items;
}

/// By the device's local calendar at [now]; only sections with items, in
/// [ActivityDay] order, the items in the order given (newest first).
List<ActivitySection> groupActivityByDay(
  List<ActivityItem> items,
  DateTime now,
) {
  final local = now.toLocal();
  final today = DateTime(local.year, local.month, local.day);
  final yesterday = DateTime(local.year, local.month, local.day - 1);
  final groups = {for (final day in ActivityDay.values) day: <ActivityItem>[]};
  for (final item in items) {
    final created = item.created.toLocal();
    final day = switch (created) {
      _ when !created.isBefore(today) => ActivityDay.today,
      _ when !created.isBefore(yesterday) => ActivityDay.yesterday,
      _ => ActivityDay.earlier,
    };
    groups[day]!.add(item);
  }
  return [
    for (final day in ActivityDay.values)
      if (groups[day]!.isNotEmpty) ActivitySection(day, groups[day]!),
  ];
}
