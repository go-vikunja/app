import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'clock_provider.g.dart';

/// Overridden in tests that need a fixed "now".
@Riverpod(keepAlive: true)
DateTime Function() clock(Ref ref) => DateTime.now;

/// The device's offset from UTC at an instant; overridden in tests that
/// need a fixed time zone.
@Riverpod(keepAlive: true)
Duration Function(DateTime utc) utcOffsetAt(Ref ref) => deviceUtcOffsetAt;

Duration deviceUtcOffsetAt(DateTime utc) => utc.toLocal().timeZoneOffset;
