// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// How many notifications the OS holds for [accountId]: the rows of its
/// `scheduled_notifications` table.

@ProviderFor(scheduledNotificationCount)
final scheduledNotificationCountProvider = ScheduledNotificationCountFamily._();

/// How many notifications the OS holds for [accountId]: the rows of its
/// `scheduled_notifications` table.

final class ScheduledNotificationCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  /// How many notifications the OS holds for [accountId]: the rows of its
  /// `scheduled_notifications` table.
  ScheduledNotificationCountProvider._({
    required ScheduledNotificationCountFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'scheduledNotificationCountProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$scheduledNotificationCountHash();

  @override
  String toString() {
    return r'scheduledNotificationCountProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    final argument = this.argument as String;
    return scheduledNotificationCount(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ScheduledNotificationCountProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$scheduledNotificationCountHash() =>
    r'c5e243e722263832cc67e53ffc4d4b7372179423';

/// How many notifications the OS holds for [accountId]: the rows of its
/// `scheduled_notifications` table.

final class ScheduledNotificationCountFamily extends $Family
    with $FunctionalFamilyOverride<Stream<int>, String> {
  ScheduledNotificationCountFamily._()
    : super(
        retry: null,
        name: r'scheduledNotificationCountProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// How many notifications the OS holds for [accountId]: the rows of its
  /// `scheduled_notifications` table.

  ScheduledNotificationCountProvider call(String accountId) =>
      ScheduledNotificationCountProvider._(argument: accountId, from: this);

  @override
  String toString() => r'scheduledNotificationCountProvider';
}

/// Taps on notifications: the plugin's responses while the app runs,
/// without the actions (those run in the background engine), and the
/// response that launched it.

@ProviderFor(notificationTapSource)
final notificationTapSourceProvider = NotificationTapSourceProvider._();

/// Taps on notifications: the plugin's responses while the app runs,
/// without the actions (those run in the background engine), and the
/// response that launched it.

final class NotificationTapSourceProvider
    extends
        $FunctionalProvider<
          NotificationTapSource,
          NotificationTapSource,
          NotificationTapSource
        >
    with $Provider<NotificationTapSource> {
  /// Taps on notifications: the plugin's responses while the app runs,
  /// without the actions (those run in the background engine), and the
  /// response that launched it.
  NotificationTapSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationTapSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationTapSourceHash();

  @$internal
  @override
  $ProviderElement<NotificationTapSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationTapSource create(Ref ref) {
    return notificationTapSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationTapSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationTapSource>(value),
    );
  }
}

String _$notificationTapSourceHash() =>
    r'cb3488de85c9d26ede6deabef9b286bbd44e0c2c';
