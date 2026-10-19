// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'smart_list_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// By title; stays loading while no account is signed in.

@ProviderFor(savedFilters)
final savedFiltersProvider = SavedFiltersProvider._();

/// By title; stays loading while no account is signed in.

final class SavedFiltersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SavedFilterRef>>,
          List<SavedFilterRef>,
          Stream<List<SavedFilterRef>>
        >
    with
        $FutureModifier<List<SavedFilterRef>>,
        $StreamProvider<List<SavedFilterRef>> {
  /// By title; stays loading while no account is signed in.
  SavedFiltersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'savedFiltersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$savedFiltersHash();

  @$internal
  @override
  $StreamProviderElement<List<SavedFilterRef>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<SavedFilterRef>> create(Ref ref) {
    return savedFilters(ref);
  }
}

String _$savedFiltersHash() => r'2589ce5970fe50aea247f8035ef11ceeeb181e6a';

/// The Favorites list; stays loading while no account is signed in.

@ProviderFor(favoriteTasks)
final favoriteTasksProvider = FavoriteTasksProvider._();

/// The Favorites list; stays loading while no account is signed in.

final class FavoriteTasksProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Task>>,
          List<Task>,
          Stream<List<Task>>
        >
    with $FutureModifier<List<Task>>, $StreamProvider<List<Task>> {
  /// The Favorites list; stays loading while no account is signed in.
  FavoriteTasksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'favoriteTasksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$favoriteTasksHash();

  @$internal
  @override
  $StreamProviderElement<List<Task>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Task>> create(Ref ref) {
    return favoriteTasks(ref);
  }
}

String _$favoriteTasksHash() => r'21ceb18fe43a67abac7ad9cab84a1f5e12298eb9';

/// Stays loading while no account is signed in.

@ProviderFor(savedFilterTasks)
final savedFilterTasksProvider = SavedFilterTasksFamily._();

/// Stays loading while no account is signed in.

final class SavedFilterTasksProvider
    extends
        $FunctionalProvider<
          AsyncValue<SavedFilterTasks>,
          SavedFilterTasks,
          Stream<SavedFilterTasks>
        >
    with $FutureModifier<SavedFilterTasks>, $StreamProvider<SavedFilterTasks> {
  /// Stays loading while no account is signed in.
  SavedFilterTasksProvider._({
    required SavedFilterTasksFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'savedFilterTasksProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$savedFilterTasksHash();

  @override
  String toString() {
    return r'savedFilterTasksProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<SavedFilterTasks> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<SavedFilterTasks> create(Ref ref) {
    final argument = this.argument as int;
    return savedFilterTasks(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SavedFilterTasksProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$savedFilterTasksHash() => r'0dfca236b2b7602a60b63774a69ae3c90d9cca30';

/// Stays loading while no account is signed in.

final class SavedFilterTasksFamily extends $Family
    with $FunctionalFamilyOverride<Stream<SavedFilterTasks>, int> {
  SavedFilterTasksFamily._()
    : super(
        retry: null,
        name: r'savedFilterTasksProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Stays loading while no account is signed in.

  SavedFilterTasksProvider call(int pseudoProjectId) =>
      SavedFilterTasksProvider._(argument: pseudoProjectId, from: this);

  @override
  String toString() => r'savedFilterTasksProvider';
}
