// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'copy_confirmation.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the system shows a copy to the clipboard itself, as Android
/// does from version 13 on; a message of the app's own would say it twice.

@ProviderFor(systemConfirmsCopies)
final systemConfirmsCopiesProvider = SystemConfirmsCopiesProvider._();

/// Whether the system shows a copy to the clipboard itself, as Android
/// does from version 13 on; a message of the app's own would say it twice.

final class SystemConfirmsCopiesProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Whether the system shows a copy to the clipboard itself, as Android
  /// does from version 13 on; a message of the app's own would say it twice.
  SystemConfirmsCopiesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'systemConfirmsCopiesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$systemConfirmsCopiesHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return systemConfirmsCopies(ref);
  }
}

String _$systemConfirmsCopiesHash() =>
    r'b0c74c9f13c8754015eee9a564196115afc205b4';
