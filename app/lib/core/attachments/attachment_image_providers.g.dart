// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment_image_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// `<cache>/images`, which holds a folder per account; backups leave the
/// cache folder out on both platforms.

@ProviderFor(imageDiskCacheRoot)
final imageDiskCacheRootProvider = ImageDiskCacheRootProvider._();

/// `<cache>/images`, which holds a folder per account; backups leave the
/// cache folder out on both platforms.

final class ImageDiskCacheRootProvider
    extends
        $FunctionalProvider<
          Future<Directory> Function(),
          Future<Directory> Function(),
          Future<Directory> Function()
        >
    with $Provider<Future<Directory> Function()> {
  /// `<cache>/images`, which holds a folder per account; backups leave the
  /// cache folder out on both platforms.
  ImageDiskCacheRootProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'imageDiskCacheRootProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$imageDiskCacheRootHash();

  @$internal
  @override
  $ProviderElement<Future<Directory> Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Future<Directory> Function() create(Ref ref) {
    return imageDiskCacheRoot(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Future<Directory> Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Future<Directory> Function()>(value),
    );
  }
}

String _$imageDiskCacheRootHash() =>
    r'21edeb62712efa747e294d078367a595f777ff9e';

/// The account's attachment images and avatars on disk, shared by its two
/// memory caches. The account's sign-out deletes the folder
/// (`accountDataWiper`), and the start the folders of accounts the
/// registry does not know (`AccountDeletions.finishAll`).

@ProviderFor(accountImageDiskCache)
final accountImageDiskCacheProvider = AccountImageDiskCacheFamily._();

/// The account's attachment images and avatars on disk, shared by its two
/// memory caches. The account's sign-out deletes the folder
/// (`accountDataWiper`), and the start the folders of accounts the
/// registry does not know (`AccountDeletions.finishAll`).

final class AccountImageDiskCacheProvider
    extends $FunctionalProvider<ImageDiskCache, ImageDiskCache, ImageDiskCache>
    with $Provider<ImageDiskCache> {
  /// The account's attachment images and avatars on disk, shared by its two
  /// memory caches. The account's sign-out deletes the folder
  /// (`accountDataWiper`), and the start the folders of accounts the
  /// registry does not know (`AccountDeletions.finishAll`).
  AccountImageDiskCacheProvider._({
    required AccountImageDiskCacheFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountImageDiskCacheProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountImageDiskCacheHash();

  @override
  String toString() {
    return r'accountImageDiskCacheProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<ImageDiskCache> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ImageDiskCache create(Ref ref) {
    final argument = this.argument as String;
    return accountImageDiskCache(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImageDiskCache value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImageDiskCache>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountImageDiskCacheProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountImageDiskCacheHash() =>
    r'bed01245acd1c2ca1fb39b3ba5300da4cbcd36f0';

/// The account's attachment images and avatars on disk, shared by its two
/// memory caches. The account's sign-out deletes the folder
/// (`accountDataWiper`), and the start the folders of accounts the
/// registry does not know (`AccountDeletions.finishAll`).

final class AccountImageDiskCacheFamily extends $Family
    with $FunctionalFamilyOverride<ImageDiskCache, String> {
  AccountImageDiskCacheFamily._()
    : super(
        retry: null,
        name: r'accountImageDiskCacheProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// The account's attachment images and avatars on disk, shared by its two
  /// memory caches. The account's sign-out deletes the folder
  /// (`accountDataWiper`), and the start the folders of accounts the
  /// registry does not know (`AccountDeletions.finishAll`).

  AccountImageDiskCacheProvider call(String accountId) =>
      AccountImageDiskCacheProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountImageDiskCacheProvider';
}

/// Kept for the session and dropped when the account signs out or another
/// becomes active ([inactiveAttachmentImages]); what is on disk stays. The
/// read client is looked up per request, like the avatar cache does. An
/// original in the download cache is read from there, offline too.

@ProviderFor(accountAttachmentImages)
final accountAttachmentImagesProvider = AccountAttachmentImagesFamily._();

/// Kept for the session and dropped when the account signs out or another
/// becomes active ([inactiveAttachmentImages]); what is on disk stays. The
/// read client is looked up per request, like the avatar cache does. An
/// original in the download cache is read from there, offline too.

final class AccountAttachmentImagesProvider
    extends
        $FunctionalProvider<
          AttachmentImages,
          AttachmentImages,
          AttachmentImages
        >
    with $Provider<AttachmentImages> {
  /// Kept for the session and dropped when the account signs out or another
  /// becomes active ([inactiveAttachmentImages]); what is on disk stays. The
  /// read client is looked up per request, like the avatar cache does. An
  /// original in the download cache is read from there, offline too.
  AccountAttachmentImagesProvider._({
    required AccountAttachmentImagesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountAttachmentImagesProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountAttachmentImagesHash();

  @override
  String toString() {
    return r'accountAttachmentImagesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<AttachmentImages> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AttachmentImages create(Ref ref) {
    final argument = this.argument as String;
    return accountAttachmentImages(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AttachmentImages value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AttachmentImages>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountAttachmentImagesProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountAttachmentImagesHash() =>
    r'b00bfb7a2dce3eb54f47d3ea00c2454c6afbbd53';

/// Kept for the session and dropped when the account signs out or another
/// becomes active ([inactiveAttachmentImages]); what is on disk stays. The
/// read client is looked up per request, like the avatar cache does. An
/// original in the download cache is read from there, offline too.

final class AccountAttachmentImagesFamily extends $Family
    with $FunctionalFamilyOverride<AttachmentImages, String> {
  AccountAttachmentImagesFamily._()
    : super(
        retry: null,
        name: r'accountAttachmentImagesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Kept for the session and dropped when the account signs out or another
  /// becomes active ([inactiveAttachmentImages]); what is on disk stays. The
  /// read client is looked up per request, like the avatar cache does. An
  /// original in the download cache is read from there, offline too.

  AccountAttachmentImagesProvider call(String accountId) =>
      AccountAttachmentImagesProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountAttachmentImagesProvider';
}

/// Drops the previous account's images when another becomes active: only
/// the active account shows images, and each cache holds up to 32 MB.
/// Listened to from the start, as a provider nobody listens to is paused
/// with its listeners.

@ProviderFor(inactiveAttachmentImages)
final inactiveAttachmentImagesProvider = InactiveAttachmentImagesProvider._();

/// Drops the previous account's images when another becomes active: only
/// the active account shows images, and each cache holds up to 32 MB.
/// Listened to from the start, as a provider nobody listens to is paused
/// with its listeners.

final class InactiveAttachmentImagesProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// Drops the previous account's images when another becomes active: only
  /// the active account shows images, and each cache holds up to 32 MB.
  /// Listened to from the start, as a provider nobody listens to is paused
  /// with its listeners.
  InactiveAttachmentImagesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inactiveAttachmentImagesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inactiveAttachmentImagesHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return inactiveAttachmentImages(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$inactiveAttachmentImagesHash() =>
    r'7b2c4f4036f95a40a02dc77e7615cb40edde4243';

/// The active account's; null while nobody is signed in.

@ProviderFor(attachmentImages)
final attachmentImagesProvider = AttachmentImagesProvider._();

/// The active account's; null while nobody is signed in.

final class AttachmentImagesProvider
    extends
        $FunctionalProvider<
          AttachmentImages?,
          AttachmentImages?,
          AttachmentImages?
        >
    with $Provider<AttachmentImages?> {
  /// The active account's; null while nobody is signed in.
  AttachmentImagesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'attachmentImagesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$attachmentImagesHash();

  @$internal
  @override
  $ProviderElement<AttachmentImages?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AttachmentImages? create(Ref ref) {
    return attachmentImages(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AttachmentImages? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AttachmentImages?>(value),
    );
  }
}

String _$attachmentImagesHash() => r'1b90bbaede49c1ee90965df2a3be1514fdfc8556';

/// Inline images of descriptions and comments ask a few at a time,
/// app-wide (decision log: Descriptions, comments, attachments).

@ProviderFor(inlineImageQueue)
final inlineImageQueueProvider = InlineImageQueueProvider._();

/// Inline images of descriptions and comments ask a few at a time,
/// app-wide (decision log: Descriptions, comments, attachments).

final class InlineImageQueueProvider
    extends $FunctionalProvider<LoadQueue, LoadQueue, LoadQueue>
    with $Provider<LoadQueue> {
  /// Inline images of descriptions and comments ask a few at a time,
  /// app-wide (decision log: Descriptions, comments, attachments).
  InlineImageQueueProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inlineImageQueueProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inlineImageQueueHash();

  @$internal
  @override
  $ProviderElement<LoadQueue> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LoadQueue create(Ref ref) {
    return inlineImageQueue(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LoadQueue value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LoadQueue>(value),
    );
  }
}

String _$inlineImageQueueHash() => r'4128a81a1bb4eb9c87099f540566ac92de62de50';
