// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_reminder_updates.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Keeps the session reminder of every signed-in user account in step
/// while the shell listens: after each write to the account's `sync_state`
/// (a sync or an activity sync completing, which a return to the front
/// starts too), and for all of them when the notification permission
/// (read again on every return) or the device's language changes and when
/// an account needs a new sign-in or has signed in again. The ids of the
/// user accounts.

@ProviderFor(sessionReminderUpdates)
final sessionReminderUpdatesProvider = SessionReminderUpdatesProvider._();

/// Keeps the session reminder of every signed-in user account in step
/// while the shell listens: after each write to the account's `sync_state`
/// (a sync or an activity sync completing, which a return to the front
/// starts too), and for all of them when the notification permission
/// (read again on every return) or the device's language changes and when
/// an account needs a new sign-in or has signed in again. The ids of the
/// user accounts.

final class SessionReminderUpdatesProvider
    extends $FunctionalProvider<Set<String>, Set<String>, Set<String>>
    with $Provider<Set<String>> {
  /// Keeps the session reminder of every signed-in user account in step
  /// while the shell listens: after each write to the account's `sync_state`
  /// (a sync or an activity sync completing, which a return to the front
  /// starts too), and for all of them when the notification permission
  /// (read again on every return) or the device's language changes and when
  /// an account needs a new sign-in or has signed in again. The ids of the
  /// user accounts.
  SessionReminderUpdatesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionReminderUpdatesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionReminderUpdatesHash();

  @$internal
  @override
  $ProviderElement<Set<String>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Set<String> create(Ref ref) {
    return sessionReminderUpdates(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$sessionReminderUpdatesHash() =>
    r'bb6f57bebabcba8ad27a2d23f9e70523b161a154';
