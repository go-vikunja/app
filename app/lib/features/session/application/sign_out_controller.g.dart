// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sign_out_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// True while a sign-out runs. The shell and the account tab both need it:
/// one blocks system back, the other shows the progress.

@ProviderFor(SignOutController)
final signOutControllerProvider = SignOutControllerProvider._();

/// True while a sign-out runs. The shell and the account tab both need it:
/// one blocks system back, the other shows the progress.
final class SignOutControllerProvider
    extends $NotifierProvider<SignOutController, bool> {
  /// True while a sign-out runs. The shell and the account tab both need it:
  /// one blocks system back, the other shows the progress.
  SignOutControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'signOutControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$signOutControllerHash();

  @$internal
  @override
  SignOutController create() => SignOutController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$signOutControllerHash() => r'0ed28005303d74a14b1618c3b0d68988cf0ba076';

/// True while a sign-out runs. The shell and the account tab both need it:
/// one blocks system back, the other shows the progress.

abstract class _$SignOutController extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
