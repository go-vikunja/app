// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_refresh.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(connectionRefresh)
final connectionRefreshProvider = ConnectionRefreshProvider._();

final class ConnectionRefreshProvider
    extends
        $FunctionalProvider<
          ConnectionRefresh,
          ConnectionRefresh,
          ConnectionRefresh
        >
    with $Provider<ConnectionRefresh> {
  ConnectionRefreshProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectionRefreshProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectionRefreshHash();

  @$internal
  @override
  $ProviderElement<ConnectionRefresh> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ConnectionRefresh create(Ref ref) {
    return connectionRefresh(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConnectionRefresh value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConnectionRefresh>(value),
    );
  }
}

String _$connectionRefreshHash() => r'd9f7a87ca31f45d62c5b536fafbd7123c8e26bd0';
