// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'realtime_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Opens sockets with the app's `User-Agent`, never an `Origin`: the
/// server refuses an Origin it does not know.

@ProviderFor(realtimeConnector)
final realtimeConnectorProvider = RealtimeConnectorProvider._();

/// Opens sockets with the app's `User-Agent`, never an `Origin`: the
/// server refuses an Origin it does not know.

final class RealtimeConnectorProvider
    extends
        $FunctionalProvider<
          RealtimeConnector,
          RealtimeConnector,
          RealtimeConnector
        >
    with $Provider<RealtimeConnector> {
  /// Opens sockets with the app's `User-Agent`, never an `Origin`: the
  /// server refuses an Origin it does not know.
  RealtimeConnectorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'realtimeConnectorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$realtimeConnectorHash();

  @$internal
  @override
  $ProviderElement<RealtimeConnector> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RealtimeConnector create(Ref ref) {
    return realtimeConnector(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RealtimeConnector value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RealtimeConnector>(value),
    );
  }
}

String _$realtimeConnectorHash() => r'fc40f7fca095eda7f109fec6f36c0768380e2b85';
