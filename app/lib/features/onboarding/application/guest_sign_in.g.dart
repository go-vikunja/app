// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guest_sign_in.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(sharedProjectTitle)
final sharedProjectTitleProvider = SharedProjectTitleProvider._();

final class SharedProjectTitleProvider
    extends
        $FunctionalProvider<
          SharedProjectTitle,
          SharedProjectTitle,
          SharedProjectTitle
        >
    with $Provider<SharedProjectTitle> {
  SharedProjectTitleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sharedProjectTitleProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sharedProjectTitleHash();

  @$internal
  @override
  $ProviderElement<SharedProjectTitle> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SharedProjectTitle create(Ref ref) {
    return sharedProjectTitle(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SharedProjectTitle value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SharedProjectTitle>(value),
    );
  }
}

String _$sharedProjectTitleHash() =>
    r'074911272a987a4891079a339627a39a09c55f00';

@ProviderFor(guestSignIn)
final guestSignInProvider = GuestSignInProvider._();

final class GuestSignInProvider
    extends $FunctionalProvider<GuestSignIn, GuestSignIn, GuestSignIn>
    with $Provider<GuestSignIn> {
  GuestSignInProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'guestSignInProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$guestSignInHash();

  @$internal
  @override
  $ProviderElement<GuestSignIn> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GuestSignIn create(Ref ref) {
    return guestSignIn(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GuestSignIn value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GuestSignIn>(value),
    );
  }
}

String _$guestSignInHash() => r'db1a5af1c8745acb9e13c5734e8de2cb24826471';
