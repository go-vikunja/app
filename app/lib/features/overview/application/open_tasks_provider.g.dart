// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'open_tasks_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Stays loading while no account is signed in.

@ProviderFor(openTasks)
final openTasksProvider = OpenTasksProvider._();

/// Stays loading while no account is signed in.

final class OpenTasksProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Task>>,
          List<Task>,
          Stream<List<Task>>
        >
    with $FutureModifier<List<Task>>, $StreamProvider<List<Task>> {
  /// Stays loading while no account is signed in.
  OpenTasksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'openTasksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$openTasksHash();

  @$internal
  @override
  $StreamProviderElement<List<Task>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Task>> create(Ref ref) {
    return openTasks(ref);
  }
}

String _$openTasksHash() => r'ecdc05421af7e8f9003f55b204f1ef00d80a5d27';
