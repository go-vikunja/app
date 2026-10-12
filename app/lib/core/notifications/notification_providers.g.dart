// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(notificationPreferencesStore)
final notificationPreferencesStoreProvider =
    NotificationPreferencesStoreProvider._();

final class NotificationPreferencesStoreProvider
    extends
        $FunctionalProvider<
          NotificationPreferencesStore,
          NotificationPreferencesStore,
          NotificationPreferencesStore
        >
    with $Provider<NotificationPreferencesStore> {
  NotificationPreferencesStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationPreferencesStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationPreferencesStoreHash();

  @$internal
  @override
  $ProviderElement<NotificationPreferencesStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationPreferencesStore create(Ref ref) {
    return notificationPreferencesStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationPreferencesStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationPreferencesStore>(value),
    );
  }
}

String _$notificationPreferencesStoreHash() =>
    r'd00a5103908bc5ed4ac83b2aa489c5aa47922240';

/// One account's scheduler, reconciling when built (app start, and the
/// first run of a background action) and when the app comes back to the
/// front; null once the account is gone. Disposed with the account's
/// database on sign-out, after which [NotificationSchedulers] still holds
/// it for the wipe.

@ProviderFor(notificationScheduler)
final notificationSchedulerProvider = NotificationSchedulerFamily._();

/// One account's scheduler, reconciling when built (app start, and the
/// first run of a background action) and when the app comes back to the
/// front; null once the account is gone. Disposed with the account's
/// database on sign-out, after which [NotificationSchedulers] still holds
/// it for the wipe.

final class NotificationSchedulerProvider
    extends
        $FunctionalProvider<
          NotificationScheduler?,
          NotificationScheduler?,
          NotificationScheduler?
        >
    with $Provider<NotificationScheduler?> {
  /// One account's scheduler, reconciling when built (app start, and the
  /// first run of a background action) and when the app comes back to the
  /// front; null once the account is gone. Disposed with the account's
  /// database on sign-out, after which [NotificationSchedulers] still holds
  /// it for the wipe.
  NotificationSchedulerProvider._({
    required NotificationSchedulerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'notificationSchedulerProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$notificationSchedulerHash();

  @override
  String toString() {
    return r'notificationSchedulerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<NotificationScheduler?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationScheduler? create(Ref ref) {
    final argument = this.argument as String;
    return notificationScheduler(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationScheduler? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationScheduler?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NotificationSchedulerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$notificationSchedulerHash() =>
    r'd284711a09cb5af7c038a9d5d5ce001828fd0ca7';

/// One account's scheduler, reconciling when built (app start, and the
/// first run of a background action) and when the app comes back to the
/// front; null once the account is gone. Disposed with the account's
/// database on sign-out, after which [NotificationSchedulers] still holds
/// it for the wipe.

final class NotificationSchedulerFamily extends $Family
    with $FunctionalFamilyOverride<NotificationScheduler?, String> {
  NotificationSchedulerFamily._()
    : super(
        retry: null,
        name: r'notificationSchedulerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// One account's scheduler, reconciling when built (app start, and the
  /// first run of a background action) and when the app comes back to the
  /// front; null once the account is gone. Disposed with the account's
  /// database on sign-out, after which [NotificationSchedulers] still holds
  /// it for the wipe.

  NotificationSchedulerProvider call(String accountId) =>
      NotificationSchedulerProvider._(argument: accountId, from: this);

  @override
  String toString() => r'notificationSchedulerProvider';
}

/// One scheduler per signed-in account while the shell listens, the
/// active one included: the ids of the accounts that have one. A
/// provider nobody listens to is paused, so the shell keeps a listener on
/// it, like on `inactiveOutboxesProvider`.

@ProviderFor(accountNotificationSchedulers)
final accountNotificationSchedulersProvider =
    AccountNotificationSchedulersProvider._();

/// One scheduler per signed-in account while the shell listens, the
/// active one included: the ids of the accounts that have one. A
/// provider nobody listens to is paused, so the shell keeps a listener on
/// it, like on `inactiveOutboxesProvider`.

final class AccountNotificationSchedulersProvider
    extends $FunctionalProvider<Set<String>, Set<String>, Set<String>>
    with $Provider<Set<String>> {
  /// One scheduler per signed-in account while the shell listens, the
  /// active one included: the ids of the accounts that have one. A
  /// provider nobody listens to is paused, so the shell keeps a listener on
  /// it, like on `inactiveOutboxesProvider`.
  AccountNotificationSchedulersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountNotificationSchedulersProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountNotificationSchedulersHash();

  @$internal
  @override
  $ProviderElement<Set<String>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Set<String> create(Ref ref) {
    return accountNotificationSchedulers(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$accountNotificationSchedulersHash() =>
    r'ae434913119a596b99d4db4c7e968e50a75b372e';
