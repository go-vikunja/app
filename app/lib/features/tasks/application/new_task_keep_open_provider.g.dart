// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'new_task_keep_open_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the new-task sheet stays open after adding; off while nobody is
/// signed in.

@ProviderFor(newTaskKeepOpen)
final newTaskKeepOpenProvider = NewTaskKeepOpenProvider._();

/// Whether the new-task sheet stays open after adding; off while nobody is
/// signed in.

final class NewTaskKeepOpenProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  /// Whether the new-task sheet stays open after adding; off while nobody is
  /// signed in.
  NewTaskKeepOpenProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'newTaskKeepOpenProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$newTaskKeepOpenHash();

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    return newTaskKeepOpen(ref);
  }
}

String _$newTaskKeepOpenHash() => r'25f290f31097fff9761589f423b3695ade469429';
