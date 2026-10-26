// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sign_out_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(signOut)
final signOutProvider = SignOutProvider._();

final class SignOutProvider
    extends $FunctionalProvider<SignOut, SignOut, SignOut>
    with $Provider<SignOut> {
  SignOutProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'signOutProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$signOutHash();

  @$internal
  @override
  $ProviderElement<SignOut> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SignOut create(Ref ref) {
    return signOut(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SignOut value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SignOut>(value),
    );
  }
}

String _$signOutHash() => r'1573303b7f8de90c46a8b05c754501bb98b00d9c';
