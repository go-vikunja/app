// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connect_server_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Checks admins' registration invites on a server, without an account.

@ProviderFor(inviteLinksPorts)
final inviteLinksPortsProvider = InviteLinksPortsProvider._();

/// Checks admins' registration invites on a server, without an account.

final class InviteLinksPortsProvider
    extends
        $FunctionalProvider<
          InviteLinksPortFactory,
          InviteLinksPortFactory,
          InviteLinksPortFactory
        >
    with $Provider<InviteLinksPortFactory> {
  /// Checks admins' registration invites on a server, without an account.
  InviteLinksPortsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inviteLinksPortsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inviteLinksPortsHash();

  @$internal
  @override
  $ProviderElement<InviteLinksPortFactory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InviteLinksPortFactory create(Ref ref) {
    return inviteLinksPorts(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InviteLinksPortFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InviteLinksPortFactory>(value),
    );
  }
}

String _$inviteLinksPortsHash() => r'00539af1fca2ac06f90982b7a8e584cae20aab11';

/// A server's address, an admin's registration invite (checked on its
/// server) or a shared project's link (opened as a guest), from the
/// address field, the shared-link sheet or another app's share. The
/// secrets of links stay in this controller, never in its state.

@ProviderFor(ConnectServerController)
final connectServerControllerProvider = ConnectServerControllerProvider._();

/// A server's address, an admin's registration invite (checked on its
/// server) or a shared project's link (opened as a guest), from the
/// address field, the shared-link sheet or another app's share. The
/// secrets of links stay in this controller, never in its state.
final class ConnectServerControllerProvider
    extends $NotifierProvider<ConnectServerController, ConnectServerState> {
  /// A server's address, an admin's registration invite (checked on its
  /// server) or a shared project's link (opened as a guest), from the
  /// address field, the shared-link sheet or another app's share. The
  /// secrets of links stay in this controller, never in its state.
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
    r'c56324db92f2b8f60f27873606fce09744d22558';

/// A server's address, an admin's registration invite (checked on its
/// server) or a shared project's link (opened as a guest), from the
/// address field, the shared-link sheet or another app's share. The
/// secrets of links stay in this controller, never in its state.

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
