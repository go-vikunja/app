// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'upcoming_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Stays loading while no account is signed in.

@ProviderFor(activeOpenTasks)
final activeOpenTasksProvider = ActiveOpenTasksProvider._();

/// Stays loading while no account is signed in.

final class ActiveOpenTasksProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Task>>,
          List<Task>,
          Stream<List<Task>>
        >
    with $FutureModifier<List<Task>>, $StreamProvider<List<Task>> {
  /// Stays loading while no account is signed in.
  ActiveOpenTasksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeOpenTasksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeOpenTasksHash();

  @$internal
  @override
  $StreamProviderElement<List<Task>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Task>> create(Ref ref) {
    return activeOpenTasks(ref);
  }
}

String _$activeOpenTasksHash() => r'25adb8e93ea8b444b104d668ea7717ab8b9f4306';

@ProviderFor(upcomingPreferences)
final upcomingPreferencesProvider = UpcomingPreferencesProvider._();

final class UpcomingPreferencesProvider
    extends
        $FunctionalProvider<
          AsyncValue<UpcomingPreferences>,
          UpcomingPreferences,
          Stream<UpcomingPreferences>
        >
    with
        $FutureModifier<UpcomingPreferences>,
        $StreamProvider<UpcomingPreferences> {
  UpcomingPreferencesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'upcomingPreferencesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$upcomingPreferencesHash();

  @$internal
  @override
  $StreamProviderElement<UpcomingPreferences> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<UpcomingPreferences> create(Ref ref) {
    return upcomingPreferences(ref);
  }
}

String _$upcomingPreferencesHash() =>
    r'25920181ec9c8334c2ef858960b96e2897f5a0df';
