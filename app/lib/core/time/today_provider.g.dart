// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'today_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Local midnight of today, for what is laid out by day (the timeline's
/// default range and its today mark). It follows [clockTickProvider], so it
/// turns over within a minute of midnight while the app is in front and on
/// coming back to it, and notifies only when the day changes.

@ProviderFor(today)
final todayProvider = TodayProvider._();

/// Local midnight of today, for what is laid out by day (the timeline's
/// default range and its today mark). It follows [clockTickProvider], so it
/// turns over within a minute of midnight while the app is in front and on
/// coming back to it, and notifies only when the day changes.

final class TodayProvider
    extends $FunctionalProvider<DateTime, DateTime, DateTime>
    with $Provider<DateTime> {
  /// Local midnight of today, for what is laid out by day (the timeline's
  /// default range and its today mark). It follows [clockTickProvider], so it
  /// turns over within a minute of midnight while the app is in front and on
  /// coming back to it, and notifies only when the day changes.
  TodayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'todayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$todayHash();

  @$internal
  @override
  $ProviderElement<DateTime> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DateTime create(Ref ref) {
    return today(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime>(value),
    );
  }
}

String _$todayHash() => r'a141cf7e9065d5e37ce0abc3d2d1577a3f6de372';
