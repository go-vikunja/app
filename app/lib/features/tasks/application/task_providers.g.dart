// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every task, done ones included, without its lists or relations, for a
/// search over titles and identifiers. Stays loading without an account.

@ProviderFor(searchableTasks)
final searchableTasksProvider = SearchableTasksProvider._();

/// Every task, done ones included, without its lists or relations, for a
/// search over titles and identifiers. Stays loading without an account.

final class SearchableTasksProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Task>>,
          List<Task>,
          Stream<List<Task>>
        >
    with $FutureModifier<List<Task>>, $StreamProvider<List<Task>> {
  /// Every task, done ones included, without its lists or relations, for a
  /// search over titles and identifiers. Stays loading without an account.
  SearchableTasksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchableTasksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchableTasksHash();

  @$internal
  @override
  $StreamProviderElement<List<Task>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Task>> create(Ref ref) {
    return searchableTasks(ref);
  }
}

String _$searchableTasksHash() => r'2f46489f3eaf36d0705e383b80ed15d74b149eb4';

/// One task as the local row knows it, following a queued create across
/// its id change; null once the row is gone. Stays loading without an
/// account.

@ProviderFor(TaskById)
final taskByIdProvider = TaskByIdFamily._();

/// One task as the local row knows it, following a queued create across
/// its id change; null once the row is gone. Stays loading without an
/// account.
final class TaskByIdProvider extends $StreamNotifierProvider<TaskById, Task?> {
  /// One task as the local row knows it, following a queued create across
  /// its id change; null once the row is gone. Stays loading without an
  /// account.
  TaskByIdProvider._({
    required TaskByIdFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'taskByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$taskByIdHash();

  @override
  String toString() {
    return r'taskByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  TaskById create() => TaskById();

  @override
  bool operator ==(Object other) {
    return other is TaskByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$taskByIdHash() => r'bb7c540fb0f6008cfe65176d60cb5235c9329996';

/// One task as the local row knows it, following a queued create across
/// its id change; null once the row is gone. Stays loading without an
/// account.

final class TaskByIdFamily extends $Family
    with
        $ClassFamilyOverride<
          TaskById,
          AsyncValue<Task?>,
          Task?,
          Stream<Task?>,
          int
        > {
  TaskByIdFamily._()
    : super(
        retry: null,
        name: r'taskByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One task as the local row knows it, following a queued create across
  /// its id change; null once the row is gone. Stays loading without an
  /// account.

  TaskByIdProvider call(int taskId) =>
      TaskByIdProvider._(argument: taskId, from: this);

  @override
  String toString() => r'taskByIdProvider';
}

/// One task as the local row knows it, following a queued create across
/// its id change; null once the row is gone. Stays loading without an
/// account.

abstract class _$TaskById extends $StreamNotifier<Task?> {
  late final _$args = ref.$arg as int;
  int get taskId => _$args;

  Stream<Task?> build(int taskId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Task?>, Task?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Task?>, Task?>,
              AsyncValue<Task?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
