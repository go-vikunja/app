import 'package:meta/meta.dart';
import 'package:timezone/timezone.dart';

/// What a filter is evaluated against besides the task.
@immutable
final class FilterContext {
  const new({
    required this.now,
    required this.location,
    this.includeNulls = false,
    this.viewId,
  });

  final DateTime now;

  /// Where `now/d`, date-only values and wall times are placed: the
  /// request's `filter_timezone` on the server.
  final Location location;

  /// `filter_include_nulls`.
  final bool includeNulls;

  /// The view whose bucket a `bucket_id` condition reads; without one any
  /// of the task's buckets can satisfy it, as on `GET /tasks`.
  final int? viewId;

  @override
  bool operator ==(Object other) =>
      other is FilterContext &&
      other.now == now &&
      other.location.name == location.name &&
      other.includeNulls == includeNulls &&
      other.viewId == viewId;

  @override
  int get hashCode => Object.hash(now, location.name, includeNulls, viewId);
}

/// The zone a `filter_timezone` or a user's timezone setting names, null
/// when it is empty, `Local` (the server's own zone) or unknown (the server
/// answers 2003). Names like `GMT` or `US/Eastern` are links that only the
/// full database (`package:timezone/data/latest_all.dart`) holds.
Location? filterLocation(String timezone) {
  if (timezone.isEmpty || timezone == 'Local') return null;
  if (timezone == 'UTC') return UTC;
  try {
    return getLocation(timezone);
  } on LocationNotFoundException {
    return null;
  }
}
