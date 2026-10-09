// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connect_server_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ConnectServerController)
final connectServerControllerProvider = ConnectServerControllerProvider._();

final class ConnectServerControllerProvider
    extends $NotifierProvider<ConnectServerController, ConnectServerState> {
  ConnectServerControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectServerControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectServerControllerHash();

  @$internal
  @override
  ConnectServerController create() => ConnectServerController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConnectServerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConnectServerState>(value),
    );
  }
}

String _$connectServerControllerHash() =>
    r'd540939042652dd600e0ff91591b9b2acac6a480';

abstract class _$ConnectServerController extends $Notifier<ConnectServerState> {
  ConnectServerState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ConnectServerState, ConnectServerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ConnectServerState, ConnectServerState>,
              ConnectServerState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
