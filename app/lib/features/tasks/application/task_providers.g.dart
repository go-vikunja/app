// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One task as the local row knows it, following a queued create across
/// its id change; null once the row is gone. Stays loading without an
/// account.

@ProviderFor(taskById)
final taskByIdProvider = TaskByIdFamily._();

/// One task as the local row knows it, following a queued create across
/// its id change; null once the row is gone. Stays loading without an
/// account.

final class TaskByIdProvider
    extends $FunctionalProvider<AsyncValue<Task?>, Task?, Stream<Task?>>
    with $FutureModifier<Task?>, $StreamProvider<Task?> {
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
  $StreamProviderElement<Task?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Task?> create(Ref ref) {
    final argument = this.argument as int;
    return taskById(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TaskByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$taskByIdHash() => r'0cdcda90e52828d231951059dc1f581f6ddf5ae1';

/// One task as the local row knows it, following a queued create across
/// its id change; null once the row is gone. Stays loading without an
/// account.

final class TaskByIdFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Task?>, int> {
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
