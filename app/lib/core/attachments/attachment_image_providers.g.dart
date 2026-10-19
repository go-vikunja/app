// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment_image_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Kept for the session and dropped when the account signs out. The read
/// client is looked up per request, like the avatar cache does.

@ProviderFor(accountAttachmentImages)
final accountAttachmentImagesProvider = AccountAttachmentImagesFamily._();

/// Kept for the session and dropped when the account signs out. The read
/// client is looked up per request, like the avatar cache does.

final class AccountAttachmentImagesProvider
    extends
        $FunctionalProvider<
          AttachmentImages,
          AttachmentImages,
          AttachmentImages
        >
    with $Provider<AttachmentImages> {
  /// Kept for the session and dropped when the account signs out. The read
  /// client is looked up per request, like the avatar cache does.
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
    r'8c4987d8bb70f799f768b24ecd9ea535166e12c6';

/// Kept for the session and dropped when the account signs out. The read
/// client is looked up per request, like the avatar cache does.

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

  /// Kept for the session and dropped when the account signs out. The read
  /// client is looked up per request, like the avatar cache does.

  AccountAttachmentImagesProvider call(String accountId) =>
      AccountAttachmentImagesProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountAttachmentImagesProvider';
}

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
