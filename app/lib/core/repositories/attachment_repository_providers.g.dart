// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment_repository_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(accountAttachmentRepository)
final accountAttachmentRepositoryProvider =
    AccountAttachmentRepositoryFamily._();

final class AccountAttachmentRepositoryProvider
    extends
        $FunctionalProvider<
          AttachmentRepository,
          AttachmentRepository,
          AttachmentRepository
        >
    with $Provider<AttachmentRepository> {
  AccountAttachmentRepositoryProvider._({
    required AccountAttachmentRepositoryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountAttachmentRepositoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountAttachmentRepositoryHash();

  @override
  String toString() {
    return r'accountAttachmentRepositoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<AttachmentRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AttachmentRepository create(Ref ref) {
    final argument = this.argument as String;
    return accountAttachmentRepository(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AttachmentRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AttachmentRepository>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountAttachmentRepositoryProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountAttachmentRepositoryHash() =>
    r'39f43f81d823bd703e9589bfabb80b5222c5bc63';

final class AccountAttachmentRepositoryFamily extends $Family
    with $FunctionalFamilyOverride<AttachmentRepository, String> {
  AccountAttachmentRepositoryFamily._()
    : super(
        retry: null,
        name: r'accountAttachmentRepositoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountAttachmentRepositoryProvider call(String accountId) =>
      AccountAttachmentRepositoryProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountAttachmentRepositoryProvider';
}

/// The active account's; null while nobody is signed in.

@ProviderFor(attachmentRepository)
final attachmentRepositoryProvider = AttachmentRepositoryProvider._();

/// The active account's; null while nobody is signed in.

final class AttachmentRepositoryProvider
    extends
        $FunctionalProvider<
          AttachmentRepository?,
          AttachmentRepository?,
          AttachmentRepository?
        >
    with $Provider<AttachmentRepository?> {
  /// The active account's; null while nobody is signed in.
  AttachmentRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'attachmentRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$attachmentRepositoryHash();

  @$internal
  @override
  $ProviderElement<AttachmentRepository?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AttachmentRepository? create(Ref ref) {
    return attachmentRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AttachmentRepository? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AttachmentRepository?>(value),
    );
  }
}

String _$attachmentRepositoryHash() =>
    r'cffd7b271b5f57b1850fe8219c3dedea43fc67c3';
