// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_reminders.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(sessionReminders)
final sessionRemindersProvider = SessionRemindersProvider._();

final class SessionRemindersProvider
    extends
        $FunctionalProvider<
          SessionReminders,
          SessionReminders,
          SessionReminders
        >
    with $Provider<SessionReminders> {
  SessionRemindersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionRemindersProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionRemindersHash();

  @$internal
  @override
  $ProviderElement<SessionReminders> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SessionReminders create(Ref ref) {
    return sessionReminders(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionReminders value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionReminders>(value),
    );
  }
}

String _$sessionRemindersHash() => r'0bf4bc7ae5846924fda90a90acaf3000d07cdf07';
