// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_comments_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$taskCommentsControllerHash() =>
    r'5f40e7435c3351c9b8c787912a0468b5374caf8d';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$TaskCommentsController
    extends BuildlessAutoDisposeAsyncNotifier<List<TaskComment>> {
  late final int taskId;

  FutureOr<List<TaskComment>> build(int taskId);
}

/// See also [TaskCommentsController].
@ProviderFor(TaskCommentsController)
const taskCommentsControllerProvider = TaskCommentsControllerFamily();

/// See also [TaskCommentsController].
class TaskCommentsControllerFamily
    extends Family<AsyncValue<List<TaskComment>>> {
  /// See also [TaskCommentsController].
  const TaskCommentsControllerFamily();

  /// See also [TaskCommentsController].
  TaskCommentsControllerProvider call(int taskId) {
    return TaskCommentsControllerProvider(taskId);
  }

  @override
  TaskCommentsControllerProvider getProviderOverride(
    covariant TaskCommentsControllerProvider provider,
  ) {
    return call(provider.taskId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'taskCommentsControllerProvider';
}

/// See also [TaskCommentsController].
class TaskCommentsControllerProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<
          TaskCommentsController,
          List<TaskComment>
        > {
  /// See also [TaskCommentsController].
  TaskCommentsControllerProvider(int taskId)
    : this._internal(
        () => TaskCommentsController()..taskId = taskId,
        from: taskCommentsControllerProvider,
        name: r'taskCommentsControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$taskCommentsControllerHash,
        dependencies: TaskCommentsControllerFamily._dependencies,
        allTransitiveDependencies:
            TaskCommentsControllerFamily._allTransitiveDependencies,
        taskId: taskId,
      );

  TaskCommentsControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.taskId,
  }) : super.internal();

  final int taskId;

  @override
  FutureOr<List<TaskComment>> runNotifierBuild(
    covariant TaskCommentsController notifier,
  ) {
    return notifier.build(taskId);
  }

  @override
  Override overrideWith(TaskCommentsController Function() create) {
    return ProviderOverride(
      origin: this,
      override: TaskCommentsControllerProvider._internal(
        () => create()..taskId = taskId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        taskId: taskId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<
    TaskCommentsController,
    List<TaskComment>
  >
  createElement() {
    return _TaskCommentsControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TaskCommentsControllerProvider && other.taskId == taskId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, taskId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TaskCommentsControllerRef
    on AutoDisposeAsyncNotifierProviderRef<List<TaskComment>> {
  /// The parameter `taskId` of this provider.
  int get taskId;
}

class _TaskCommentsControllerProviderElement
    extends
        AutoDisposeAsyncNotifierProviderElement<
          TaskCommentsController,
          List<TaskComment>
        >
    with TaskCommentsControllerRef {
  _TaskCommentsControllerProviderElement(super.provider);

  @override
  int get taskId => (origin as TaskCommentsControllerProvider).taskId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
