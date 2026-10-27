// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'privacy_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(privacySettingsStore)
final privacySettingsStoreProvider = PrivacySettingsStoreProvider._();

final class PrivacySettingsStoreProvider
    extends
        $FunctionalProvider<
          PrivacySettingsStore,
          PrivacySettingsStore,
          PrivacySettingsStore
        >
    with $Provider<PrivacySettingsStore> {
  PrivacySettingsStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'privacySettingsStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$privacySettingsStoreHash();

  @$internal
  @override
  $ProviderElement<PrivacySettingsStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PrivacySettingsStore create(Ref ref) {
    return privacySettingsStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PrivacySettingsStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PrivacySettingsStore>(value),
    );
  }
}

String _$privacySettingsStoreHash() =>
    r'ff88750e6a2840864afeba9dc265cf9204415a45';

/// The writable side of the device's privacy settings. The app lock is
/// turned on and off through the app lock controller, which asks for the
/// device's screen lock first.

@ProviderFor(PrivacySettingsController)
final privacySettingsControllerProvider = PrivacySettingsControllerProvider._();

/// The writable side of the device's privacy settings. The app lock is
/// turned on and off through the app lock controller, which asks for the
/// device's screen lock first.
final class PrivacySettingsControllerProvider
    extends
        $AsyncNotifierProvider<
          PrivacySettingsController,
          StoredPrivacySettings
        > {
  /// The writable side of the device's privacy settings. The app lock is
  /// turned on and off through the app lock controller, which asks for the
  /// device's screen lock first.
  PrivacySettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'privacySettingsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$privacySettingsControllerHash();

  @$internal
  @override
  PrivacySettingsController create() => PrivacySettingsController();
}

String _$privacySettingsControllerHash() =>
    r'0c0b39dc22f43c9c2db88c950a2b6fda9f8bf587';

/// The writable side of the device's privacy settings. The app lock is
/// turned on and off through the app lock controller, which asks for the
/// device's screen lock first.

abstract class _$PrivacySettingsController
    extends $AsyncNotifier<StoredPrivacySettings> {
  FutureOr<StoredPrivacySettings> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<StoredPrivacySettings>, StoredPrivacySettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<StoredPrivacySettings>,
                StoredPrivacySettings
              >,
              AsyncValue<StoredPrivacySettings>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The settings everything else follows ([StoredPrivacySettings.effective]);
/// for the background containers too, which read them fresh on every run.

@ProviderFor(privacySettings)
final privacySettingsProvider = PrivacySettingsProvider._();

/// The settings everything else follows ([StoredPrivacySettings.effective]);
/// for the background containers too, which read them fresh on every run.

final class PrivacySettingsProvider
    extends
        $FunctionalProvider<
          AsyncValue<PrivacySettings>,
          PrivacySettings,
          FutureOr<PrivacySettings>
        >
    with $FutureModifier<PrivacySettings>, $FutureProvider<PrivacySettings> {
  /// The settings everything else follows ([StoredPrivacySettings.effective]);
  /// for the background containers too, which read them fresh on every run.
  PrivacySettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'privacySettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$privacySettingsHash();

  @$internal
  @override
  $FutureProviderElement<PrivacySettings> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PrivacySettings> create(Ref ref) {
    return privacySettings(ref);
  }
}

String _$privacySettingsHash() => r'6e75cdbe8376eaed531fcdb47f26091f45815fae';
