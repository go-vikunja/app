// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_write_access.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(taskWriteAccess)
final taskWriteAccessProvider = TaskWriteAccessProvider._();

final class TaskWriteAccessProvider
    extends
        $FunctionalProvider<TaskWriteAccess, TaskWriteAccess, TaskWriteAccess>
    with $Provider<TaskWriteAccess> {
  TaskWriteAccessProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taskWriteAccessProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taskWriteAccessHash();

  @$internal
  @override
  $ProviderElement<TaskWriteAccess> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TaskWriteAccess create(Ref ref) {
    return taskWriteAccess(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaskWriteAccess value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaskWriteAccess>(value),
    );
  }
}

String _$taskWriteAccessHash() => r'fe87ccb0c09ce16428db2f76423e39a63500eb37';
