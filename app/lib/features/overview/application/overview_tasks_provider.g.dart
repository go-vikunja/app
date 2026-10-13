// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'overview_tasks_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Stays loading while no account is signed in.

@ProviderFor(overviewTasks)
final overviewTasksProvider = OverviewTasksProvider._();

/// Stays loading while no account is signed in.

final class OverviewTasksProvider
    extends
        $FunctionalProvider<
          AsyncValue<OverviewTasks>,
          OverviewTasks,
          Stream<OverviewTasks>
        >
    with $FutureModifier<OverviewTasks>, $StreamProvider<OverviewTasks> {
  /// Stays loading while no account is signed in.
  OverviewTasksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'overviewTasksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$overviewTasksHash();

  @$internal
  @override
  $StreamProviderElement<OverviewTasks> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<OverviewTasks> create(Ref ref) {
    return overviewTasks(ref);
  }
}

String _$overviewTasksHash() => r'afbe5039ff85c6f922b24f510ebfd62e345b6658';
