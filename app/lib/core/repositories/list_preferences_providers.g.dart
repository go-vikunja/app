// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_preferences_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(accountListPreferences)
final accountListPreferencesProvider = AccountListPreferencesFamily._();

final class AccountListPreferencesProvider
    extends
        $FunctionalProvider<ListPreferences, ListPreferences, ListPreferences>
    with $Provider<ListPreferences> {
  AccountListPreferencesProvider._({
    required AccountListPreferencesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountListPreferencesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountListPreferencesHash();

  @override
  String toString() {
    return r'accountListPreferencesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<ListPreferences> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ListPreferences create(Ref ref) {
    final argument = this.argument as String;
    return accountListPreferences(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ListPreferences value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ListPreferences>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountListPreferencesProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountListPreferencesHash() =>
    r'17cf575044e75d91beb1879ee6066524b951037d';

final class AccountListPreferencesFamily extends $Family
    with $FunctionalFamilyOverride<ListPreferences, String> {
  AccountListPreferencesFamily._()
    : super(
        retry: null,
        name: r'accountListPreferencesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountListPreferencesProvider call(String accountId) =>
      AccountListPreferencesProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountListPreferencesProvider';
}

/// The active account's; null while nobody is signed in.

@ProviderFor(listPreferences)
final listPreferencesProvider = ListPreferencesProvider._();

/// The active account's; null while nobody is signed in.

final class ListPreferencesProvider
    extends
        $FunctionalProvider<
          ListPreferences?,
          ListPreferences?,
          ListPreferences?
        >
    with $Provider<ListPreferences?> {
  /// The active account's; null while nobody is signed in.
  ListPreferencesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'listPreferencesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$listPreferencesHash();

  @$internal
  @override
  $ProviderElement<ListPreferences?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ListPreferences? create(Ref ref) {
    return listPreferences(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ListPreferences? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ListPreferences?>(value),
    );
  }
}

String _$listPreferencesHash() => r'eb25d6b0d7f72451a23e7b03646f72a51256f617';
