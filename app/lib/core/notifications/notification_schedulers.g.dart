// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_schedulers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(notificationSchedulers)
final notificationSchedulersProvider = NotificationSchedulersProvider._();

final class NotificationSchedulersProvider
    extends
        $FunctionalProvider<
          NotificationSchedulers,
          NotificationSchedulers,
          NotificationSchedulers
        >
    with $Provider<NotificationSchedulers> {
  NotificationSchedulersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationSchedulersProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationSchedulersHash();

  @$internal
  @override
  $ProviderElement<NotificationSchedulers> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationSchedulers create(Ref ref) {
    return notificationSchedulers(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationSchedulers value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationSchedulers>(value),
    );
  }
}

String _$notificationSchedulersHash() =>
    r'fcd920a39b6f925ae81ec8edafccc2b19e64c338';
