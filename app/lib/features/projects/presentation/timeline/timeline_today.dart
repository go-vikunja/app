import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'timeline_today.g.dart';

/// Counts the requests to scroll a Gantt view's timeline to today, from
/// the button above it; the timeline scrolls on each.
@riverpod
class TimelineTodayRequests extends _$TimelineTodayRequests {
  @override
  int build(int viewId) => 0;

  void request() => state++;
}
