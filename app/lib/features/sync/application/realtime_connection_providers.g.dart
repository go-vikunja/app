// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'realtime_connection_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The active account's socket, gated and driven like the foreground sync
/// scheduler: replaced on an account switch; gone in a background
/// container, while nobody is signed in, before the account's first sync,
/// while its session needs a new sign-in, during a sign-out and on a server
/// without websockets; closed while the app is not in front or nothing
/// listens (the shell does).

@ProviderFor(realtimeConnection)
final realtimeConnectionProvider = RealtimeConnectionProvider._();

/// The active account's socket, gated and driven like the foreground sync
/// scheduler: replaced on an account switch; gone in a background
/// container, while nobody is signed in, before the account's first sync,
/// while its session needs a new sign-in, during a sign-out and on a server
/// without websockets; closed while the app is not in front or nothing
/// listens (the shell does).

final class RealtimeConnectionProvider
    extends
        $FunctionalProvider<
          RealtimeConnection?,
          RealtimeConnection?,
          RealtimeConnection?
        >
    with $Provider<RealtimeConnection?> {
  /// The active account's socket, gated and driven like the foreground sync
  /// scheduler: replaced on an account switch; gone in a background
  /// container, while nobody is signed in, before the account's first sync,
  /// while its session needs a new sign-in, during a sign-out and on a server
  /// without websockets; closed while the app is not in front or nothing
  /// listens (the shell does).
  RealtimeConnectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'realtimeConnectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$realtimeConnectionHash();

  @$internal
  @override
  $ProviderElement<RealtimeConnection?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RealtimeConnection? create(Ref ref) {
    return realtimeConnection(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RealtimeConnection? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RealtimeConnection?>(value),
    );
  }
}

String _$realtimeConnectionHash() =>
    r'8a9807c39dee1c19a2f4bb483754f16581bacb45';
