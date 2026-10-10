// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clock_tick_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// "Now" for everything on screen that depends on the time of day: re-read
/// when the app comes back to the foreground and every minute while it is in
/// front, so due-date sections and relative labels never freeze. Backgrounded,
/// nothing ticks.

@ProviderFor(ClockTick)
final clockTickProvider = ClockTickProvider._();

/// "Now" for everything on screen that depends on the time of day: re-read
/// when the app comes back to the foreground and every minute while it is in
/// front, so due-date sections and relative labels never freeze. Backgrounded,
/// nothing ticks.
final class ClockTickProvider extends $NotifierProvider<ClockTick, DateTime> {
  /// "Now" for everything on screen that depends on the time of day: re-read
  /// when the app comes back to the foreground and every minute while it is in
  /// front, so due-date sections and relative labels never freeze. Backgrounded,
  /// nothing ticks.
  ClockTickProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clockTickProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clockTickHash();

  @$internal
  @override
  ClockTick create() => ClockTick();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime>(value),
    );
  }
}

String _$clockTickHash() => r'1cabdc29d267162e2da7246b7bc3aabef3a23113';

/// "Now" for everything on screen that depends on the time of day: re-read
/// when the app comes back to the foreground and every minute while it is in
/// front, so due-date sections and relative labels never freeze. Backgrounded,
/// nothing ticks.

abstract class _$ClockTick extends $Notifier<DateTime> {
  DateTime build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DateTime, DateTime>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DateTime, DateTime>,
              DateTime,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
