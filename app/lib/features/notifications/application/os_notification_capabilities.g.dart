// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'os_notification_capabilities.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// What the OS allows right now; read again whenever the app comes back to
/// the front, because the user changes it in the system settings.

@ProviderFor(OsNotificationCapabilities)
final osNotificationCapabilitiesProvider =
    OsNotificationCapabilitiesProvider._();

/// What the OS allows right now; read again whenever the app comes back to
/// the front, because the user changes it in the system settings.
final class OsNotificationCapabilitiesProvider
    extends
        $AsyncNotifierProvider<
          OsNotificationCapabilities,
          NotificationCapabilities
        > {
  /// What the OS allows right now; read again whenever the app comes back to
  /// the front, because the user changes it in the system settings.
  OsNotificationCapabilitiesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'osNotificationCapabilitiesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$osNotificationCapabilitiesHash();

  @$internal
  @override
  OsNotificationCapabilities create() => OsNotificationCapabilities();
}

String _$osNotificationCapabilitiesHash() =>
    r'17d28340a03b06e4d7401f00ca6b3b1b032f386a';

/// What the OS allows right now; read again whenever the app comes back to
/// the front, because the user changes it in the system settings.

abstract class _$OsNotificationCapabilities
    extends $AsyncNotifier<NotificationCapabilities> {
  FutureOr<NotificationCapabilities> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<NotificationCapabilities>,
              NotificationCapabilities
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<NotificationCapabilities>,
                NotificationCapabilities
              >,
              AsyncValue<NotificationCapabilities>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
