// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_profile_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One table for both Dios and the realtime socket. It depends only on the
/// stores, so nothing rebuilds the Dios when a profile changes, and every
/// container (background ones too) loads it lazily on the first request.

@ProviderFor(networkProfiles)
final networkProfilesProvider = NetworkProfilesProvider._();

/// One table for both Dios and the realtime socket. It depends only on the
/// stores, so nothing rebuilds the Dios when a profile changes, and every
/// container (background ones too) loads it lazily on the first request.

final class NetworkProfilesProvider
    extends
        $FunctionalProvider<NetworkProfiles, NetworkProfiles, NetworkProfiles>
    with $Provider<NetworkProfiles> {
  /// One table for both Dios and the realtime socket. It depends only on the
  /// stores, so nothing rebuilds the Dios when a profile changes, and every
  /// container (background ones too) loads it lazily on the first request.
  NetworkProfilesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'networkProfilesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$networkProfilesHash();

  @$internal
  @override
  $ProviderElement<NetworkProfiles> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NetworkProfiles create(Ref ref) {
    return networkProfiles(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NetworkProfiles value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NetworkProfiles>(value),
    );
  }
}

String _$networkProfilesHash() => r'c3fc321a9385670f6fda8ace57156ab3362e10a1';

/// [origin]'s settings for screens, read afresh when first listened to and
/// on every resume, and again after every change made in this isolate.

@ProviderFor(connectionProfile)
final connectionProfileProvider = ConnectionProfileFamily._();

/// [origin]'s settings for screens, read afresh when first listened to and
/// on every resume, and again after every change made in this isolate.

final class ConnectionProfileProvider
    extends
        $FunctionalProvider<
          AsyncValue<ConnectionProfileState>,
          ConnectionProfileState,
          Stream<ConnectionProfileState>
        >
    with
        $FutureModifier<ConnectionProfileState>,
        $StreamProvider<ConnectionProfileState> {
  /// [origin]'s settings for screens, read afresh when first listened to and
  /// on every resume, and again after every change made in this isolate.
  ConnectionProfileProvider._({
    required ConnectionProfileFamily super.from,
    required OriginKey super.argument,
  }) : super(
         retry: null,
         name: r'connectionProfileProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$connectionProfileHash();

  @override
  String toString() {
    return r'connectionProfileProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<ConnectionProfileState> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<ConnectionProfileState> create(Ref ref) {
    final argument = this.argument as OriginKey;
    return connectionProfile(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ConnectionProfileProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$connectionProfileHash() => r'7add675fdab41c4f86e22f40f83f4f8e4f73f7e0';

/// [origin]'s settings for screens, read afresh when first listened to and
/// on every resume, and again after every change made in this isolate.

final class ConnectionProfileFamily extends $Family
    with $FunctionalFamilyOverride<Stream<ConnectionProfileState>, OriginKey> {
  ConnectionProfileFamily._()
    : super(
        retry: null,
        name: r'connectionProfileProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// [origin]'s settings for screens, read afresh when first listened to and
  /// on every resume, and again after every change made in this isolate.

  ConnectionProfileProvider call(OriginKey origin) =>
      ConnectionProfileProvider._(argument: origin, from: this);

  @override
  String toString() => r'connectionProfileProvider';
}

/// Null until [connectionProfileProvider] read [origin] once.

@ProviderFor(connectionProfileRevision)
final connectionProfileRevisionProvider = ConnectionProfileRevisionFamily._();

/// Null until [connectionProfileProvider] read [origin] once.

final class ConnectionProfileRevisionProvider
    extends
        $FunctionalProvider<
          ConnectionProfileRevision?,
          ConnectionProfileRevision?,
          ConnectionProfileRevision?
        >
    with $Provider<ConnectionProfileRevision?> {
  /// Null until [connectionProfileProvider] read [origin] once.
  ConnectionProfileRevisionProvider._({
    required ConnectionProfileRevisionFamily super.from,
    required OriginKey super.argument,
  }) : super(
         retry: null,
         name: r'connectionProfileRevisionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$connectionProfileRevisionHash();

  @override
  String toString() {
    return r'connectionProfileRevisionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<ConnectionProfileRevision?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ConnectionProfileRevision? create(Ref ref) {
    final argument = this.argument as OriginKey;
    return connectionProfileRevision(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConnectionProfileRevision? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConnectionProfileRevision?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ConnectionProfileRevisionProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$connectionProfileRevisionHash() =>
    r'e83870b1178f018a3e295049b9c691ce6b05cfc8';

/// Null until [connectionProfileProvider] read [origin] once.

final class ConnectionProfileRevisionFamily extends $Family
    with $FunctionalFamilyOverride<ConnectionProfileRevision?, OriginKey> {
  ConnectionProfileRevisionFamily._()
    : super(
        retry: null,
        name: r'connectionProfileRevisionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Null until [connectionProfileProvider] read [origin] once.

  ConnectionProfileRevisionProvider call(OriginKey origin) =>
      ConnectionProfileRevisionProvider._(argument: origin, from: this);

  @override
  String toString() => r'connectionProfileRevisionProvider';
}

@ProviderFor(certificateProbe)
final certificateProbeProvider = CertificateProbeProvider._();

final class CertificateProbeProvider
    extends
        $FunctionalProvider<
          CertificateProbe,
          CertificateProbe,
          CertificateProbe
        >
    with $Provider<CertificateProbe> {
  CertificateProbeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'certificateProbeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$certificateProbeHash();

  @$internal
  @override
  $ProviderElement<CertificateProbe> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CertificateProbe create(Ref ref) {
    return certificateProbe(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CertificateProbe value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CertificateProbe>(value),
    );
  }
}

String _$certificateProbeHash() => r'5cd01f5ba485b15e5cb1608b545f26a76816fe96';
