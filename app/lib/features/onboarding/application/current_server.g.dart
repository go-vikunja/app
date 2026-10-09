// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'current_server.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The server the user confirmed, including consent to plain http.

@ProviderFor(CurrentServer)
final currentServerProvider = CurrentServerProvider._();

/// The server the user confirmed, including consent to plain http.
final class CurrentServerProvider
    extends $NotifierProvider<CurrentServer, ServerConnection?> {
  /// The server the user confirmed, including consent to plain http.
  CurrentServerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentServerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentServerHash();

  @$internal
  @override
  CurrentServer create() => CurrentServer();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ServerConnection? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ServerConnection?>(value),
    );
  }
}

String _$currentServerHash() => r'0f86402f482ce8e8bcd21b6280fe89ed752f6ab5';

/// The server the user confirmed, including consent to plain http.

abstract class _$CurrentServer extends $Notifier<ServerConnection?> {
  ServerConnection? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ServerConnection?, ServerConnection?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ServerConnection?, ServerConnection?>,
              ServerConnection?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
