// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'outbox_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Queued changes of the active account; 0 while nobody is signed in.

@ProviderFor(pendingChanges)
final pendingChangesProvider = PendingChangesProvider._();

/// Queued changes of the active account; 0 while nobody is signed in.

final class PendingChangesProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  /// Queued changes of the active account; 0 while nobody is signed in.
  PendingChangesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingChangesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingChangesHash();

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    return pendingChanges(ref);
  }
}

String _$pendingChangesHash() => r'd42b3d36cf62dcdd87f2f3e254c731c1c7278d5c';

@ProviderFor(syncProblems)
final syncProblemsProvider = SyncProblemsProvider._();

final class SyncProblemsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SyncProblem>>,
          List<SyncProblem>,
          Stream<List<SyncProblem>>
        >
    with
        $FutureModifier<List<SyncProblem>>,
        $StreamProvider<List<SyncProblem>> {
  SyncProblemsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncProblemsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncProblemsHash();

  @$internal
  @override
  $StreamProviderElement<List<SyncProblem>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<SyncProblem>> create(Ref ref) {
    return syncProblems(ref);
  }
}

String _$syncProblemsHash() => r'c4109c8ee4db88b4c20a380ea9518d1a6c2b8ddb';

/// Empty for a repository without a [PendingTaskIdsSource].

@ProviderFor(pendingTaskIds)
final pendingTaskIdsProvider = PendingTaskIdsProvider._();

/// Empty for a repository without a [PendingTaskIdsSource].

final class PendingTaskIdsProvider
    extends
        $FunctionalProvider<AsyncValue<Set<int>>, Set<int>, Stream<Set<int>>>
    with $FutureModifier<Set<int>>, $StreamProvider<Set<int>> {
  /// Empty for a repository without a [PendingTaskIdsSource].
  PendingTaskIdsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingTaskIdsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingTaskIdsHash();

  @$internal
  @override
  $StreamProviderElement<Set<int>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Set<int>> create(Ref ref) {
    return pendingTaskIds(ref);
  }
}

String _$pendingTaskIdsHash() => r'0a124b1fa8e6800f9647a493c1162d0bdfd1d781';
