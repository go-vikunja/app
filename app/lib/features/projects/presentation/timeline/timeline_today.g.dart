// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timeline_today.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Counts the requests to scroll a Gantt view's timeline to today, from
/// the button above it; the timeline scrolls on each.

@ProviderFor(TimelineTodayRequests)
final timelineTodayRequestsProvider = TimelineTodayRequestsFamily._();

/// Counts the requests to scroll a Gantt view's timeline to today, from
/// the button above it; the timeline scrolls on each.
final class TimelineTodayRequestsProvider
    extends $NotifierProvider<TimelineTodayRequests, int> {
  /// Counts the requests to scroll a Gantt view's timeline to today, from
  /// the button above it; the timeline scrolls on each.
  TimelineTodayRequestsProvider._({
    required TimelineTodayRequestsFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'timelineTodayRequestsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$timelineTodayRequestsHash();

  @override
  String toString() {
    return r'timelineTodayRequestsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  TimelineTodayRequests create() => TimelineTodayRequests();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TimelineTodayRequestsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$timelineTodayRequestsHash() =>
    r'486486d1f722ec5b9fcceb7f6e283a97242cf53a';

/// Counts the requests to scroll a Gantt view's timeline to today, from
/// the button above it; the timeline scrolls on each.

final class TimelineTodayRequestsFamily extends $Family
    with $ClassFamilyOverride<TimelineTodayRequests, int, int, int, int> {
  TimelineTodayRequestsFamily._()
    : super(
        retry: null,
        name: r'timelineTodayRequestsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Counts the requests to scroll a Gantt view's timeline to today, from
  /// the button above it; the timeline scrolls on each.

  TimelineTodayRequestsProvider call(int viewId) =>
      TimelineTodayRequestsProvider._(argument: viewId, from: this);

  @override
  String toString() => r'timelineTodayRequestsProvider';
}

/// Counts the requests to scroll a Gantt view's timeline to today, from
/// the button above it; the timeline scrolls on each.

abstract class _$TimelineTodayRequests extends $Notifier<int> {
  late final _$args = ref.$arg as int;
  int get viewId => _$args;

  int build(int viewId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
