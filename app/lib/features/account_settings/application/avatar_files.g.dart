// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'avatar_files.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(avatarFiles)
final avatarFilesProvider = AvatarFilesProvider._();

final class AvatarFilesProvider
    extends $FunctionalProvider<AvatarFiles, AvatarFiles, AvatarFiles>
    with $Provider<AvatarFiles> {
  AvatarFilesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'avatarFilesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$avatarFilesHash();

  @$internal
  @override
  $ProviderElement<AvatarFiles> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AvatarFiles create(Ref ref) {
    return avatarFiles(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AvatarFiles value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AvatarFiles>(value),
    );
  }
}

String _$avatarFilesHash() => r'92eefe6404f5c8078481e88a84402a8cea8dfab3';
