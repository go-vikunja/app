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

/// On Android share_plus shares a copy of each file from `<cache>/share_plus`
/// and empties that folder only when the next share starts; a sign-out
/// deletes it (`accountDataWiper`). Never when a share returns: the app it
/// went to may still be reading it (decision log: Security and privacy).
/// iOS shares the file itself.

@ProviderFor(shareCopiesFolder)
final shareCopiesFolderProvider = ShareCopiesFolderProvider._();

/// On Android share_plus shares a copy of each file from `<cache>/share_plus`
/// and empties that folder only when the next share starts; a sign-out
/// deletes it (`accountDataWiper`). Never when a share returns: the app it
/// went to may still be reading it (decision log: Security and privacy).
/// iOS shares the file itself.

final class ShareCopiesFolderProvider
    extends
        $FunctionalProvider<
          Future<Directory> Function(),
          Future<Directory> Function(),
          Future<Directory> Function()
        >
    with $Provider<Future<Directory> Function()> {
  /// On Android share_plus shares a copy of each file from `<cache>/share_plus`
  /// and empties that folder only when the next share starts; a sign-out
  /// deletes it (`accountDataWiper`). Never when a share returns: the app it
  /// went to may still be reading it (decision log: Security and privacy).
  /// iOS shares the file itself.
  ShareCopiesFolderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shareCopiesFolderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shareCopiesFolderHash();

  @$internal
  @override
  $ProviderElement<Future<Directory> Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Future<Directory> Function() create(Ref ref) {
    return shareCopiesFolder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Future<Directory> Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Future<Directory> Function()>(value),
    );
  }
}

String _$shareCopiesFolderHash() => r'08440264f6e3de58a70da275a1d2adefdaf4b010';
