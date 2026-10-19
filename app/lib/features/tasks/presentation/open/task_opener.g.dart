// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_opener.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(taskOpener)
final taskOpenerProvider = TaskOpenerProvider._();

final class TaskOpenerProvider
    extends $FunctionalProvider<TaskOpener, TaskOpener, TaskOpener>
    with $Provider<TaskOpener> {
  TaskOpenerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taskOpenerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taskOpenerHash();

  @$internal
  @override
  $ProviderElement<TaskOpener> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TaskOpener create(Ref ref) {
    return taskOpener(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaskOpener value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaskOpener>(value),
    );
  }
}

String _$taskOpenerHash() => r'e9e0737292188f24cfc8983c5b010a33a38f03bc';
