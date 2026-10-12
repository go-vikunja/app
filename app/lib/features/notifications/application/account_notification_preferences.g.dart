// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_notification_preferences.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One account's switches: the stored value, then every write.

@ProviderFor(accountNotificationPreferences)
final accountNotificationPreferencesProvider =
    AccountNotificationPreferencesFamily._();

/// One account's switches: the stored value, then every write.

final class AccountNotificationPreferencesProvider
    extends
        $FunctionalProvider<
          AsyncValue<NotificationPreferences>,
          NotificationPreferences,
          Stream<NotificationPreferences>
        >
    with
        $FutureModifier<NotificationPreferences>,
        $StreamProvider<NotificationPreferences> {
  /// One account's switches: the stored value, then every write.
  AccountNotificationPreferencesProvider._({
    required AccountNotificationPreferencesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountNotificationPreferencesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountNotificationPreferencesHash();

  @override
  String toString() {
    return r'accountNotificationPreferencesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<NotificationPreferences> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<NotificationPreferences> create(Ref ref) {
    final argument = this.argument as String;
    return accountNotificationPreferences(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AccountNotificationPreferencesProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountNotificationPreferencesHash() =>
    r'1c29a57a08feaf5a2a160f3729cd59bc7e49f94a';

/// One account's switches: the stored value, then every write.

final class AccountNotificationPreferencesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<NotificationPreferences>, String> {
  AccountNotificationPreferencesFamily._()
    : super(
        retry: null,
        name: r'accountNotificationPreferencesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One account's switches: the stored value, then every write.

  AccountNotificationPreferencesProvider call(String accountId) =>
      AccountNotificationPreferencesProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountNotificationPreferencesProvider';
}
