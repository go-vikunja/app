import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';

part 'today_provider.g.dart';

/// Local midnight of today, for what is laid out by day (the timeline's
/// default range and its today mark). It follows [clockTickProvider], so it
/// turns over within a minute of midnight while the app is in front and on
/// coming back to it, and notifies only when the day changes.
@Riverpod(keepAlive: true)
DateTime today(Ref ref) => ref.watch(
  clockTickProvider.select((now) {
    final local = now.toLocal();
    return DateTime(local.year, local.month, local.day);
  }),
);
