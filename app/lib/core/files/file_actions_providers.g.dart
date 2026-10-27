// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_actions_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(fileActions)
final fileActionsProvider = FileActionsProvider._();

final class FileActionsProvider
    extends $FunctionalProvider<FileActions, FileActions, FileActions>
    with $Provider<FileActions> {
  FileActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fileActionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fileActionsHash();

  @$internal
  @override
  $ProviderElement<FileActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FileActions create(Ref ref) {
    return fileActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FileActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FileActions>(value),
    );
  }
}

String _$fileActionsHash() => r'346e175b5de5683a5c88f8d554b4d5f6ce1efd27';
