// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inactive_outboxes.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(accountOutboxes)
final accountOutboxesProvider = AccountOutboxesProvider._();

final class AccountOutboxesProvider
    extends
        $FunctionalProvider<AccountOutboxes, AccountOutboxes, AccountOutboxes>
    with $Provider<AccountOutboxes> {
  AccountOutboxesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountOutboxesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountOutboxesHash();

  @$internal
  @override
  $ProviderElement<AccountOutboxes> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AccountOutboxes create(Ref ref) {
    return accountOutboxes(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountOutboxes value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountOutboxes>(value),
    );
  }
}

String _$accountOutboxesHash() => r'81da3b92434c14976ba9f12769f01d6c31870635';

/// Checks the inactive accounts' outboxes while the shell listens: when it
/// starts listening, when the app comes back to the front and when the
/// accounts change. Gone during a sign-out, whose wipe a new sender would
/// race; built again, and so checking again, once it is over. The active
/// account's sender has its own triggers.

@ProviderFor(inactiveOutboxes)
final inactiveOutboxesProvider = InactiveOutboxesProvider._();

/// Checks the inactive accounts' outboxes while the shell listens: when it
/// starts listening, when the app comes back to the front and when the
/// accounts change. Gone during a sign-out, whose wipe a new sender would
/// race; built again, and so checking again, once it is over. The active
/// account's sender has its own triggers.

final class InactiveOutboxesProvider
    extends
        $FunctionalProvider<
          InactiveOutboxes?,
          InactiveOutboxes?,
          InactiveOutboxes?
        >
    with $Provider<InactiveOutboxes?> {
  /// Checks the inactive accounts' outboxes while the shell listens: when it
  /// starts listening, when the app comes back to the front and when the
  /// accounts change. Gone during a sign-out, whose wipe a new sender would
  /// race; built again, and so checking again, once it is over. The active
  /// account's sender has its own triggers.
  InactiveOutboxesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inactiveOutboxesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inactiveOutboxesHash();

  @$internal
  @override
  $ProviderElement<InactiveOutboxes?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InactiveOutboxes? create(Ref ref) {
    return inactiveOutboxes(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InactiveOutboxes? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InactiveOutboxes?>(value),
    );
  }
}

String _$inactiveOutboxesHash() => r'8ffb2312f317bedce23028a07d4d614142aad151';
