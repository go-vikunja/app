// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_detail_pane.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(taskDetailPanes)
final taskDetailPanesProvider = TaskDetailPanesProvider._();

final class TaskDetailPanesProvider
    extends
        $FunctionalProvider<TaskDetailPanes, TaskDetailPanes, TaskDetailPanes>
    with $Provider<TaskDetailPanes> {
  TaskDetailPanesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taskDetailPanesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taskDetailPanesHash();

  @$internal
  @override
  $ProviderElement<TaskDetailPanes> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TaskDetailPanes create(Ref ref) {
    return taskDetailPanes(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaskDetailPanes value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaskDetailPanes>(value),
    );
  }
}

String _$taskDetailPanesHash() => r'c7911e70ae5fbb2dac584c7833302d04e0d5edba';
