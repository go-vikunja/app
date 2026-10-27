// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_notification_gateway_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(notificationGateway)
final notificationGatewayProvider = NotificationGatewayProvider._();

final class NotificationGatewayProvider
    extends
        $FunctionalProvider<
          NotificationGateway,
          NotificationGateway,
          NotificationGateway
        >
    with $Provider<NotificationGateway> {
  NotificationGatewayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationGatewayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationGatewayHash();

  @$internal
  @override
  $ProviderElement<NotificationGateway> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationGateway create(Ref ref) {
    return notificationGateway(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationGateway value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationGateway>(value),
    );
  }
}

String _$notificationGatewayHash() =>
    r'fcad7229944aaacdec9da7d857f3dd9a5feb5e0c';

/// The top-level `@pragma('vm:entry-point')` function the plugin runs in its
/// own engine for an action that shows no UI. Overridden in bootstrap with
/// the action handler's entry point; null leaves those actions unwired.

@ProviderFor(notificationBackgroundEntryPoint)
final notificationBackgroundEntryPointProvider =
    NotificationBackgroundEntryPointProvider._();

/// The top-level `@pragma('vm:entry-point')` function the plugin runs in its
/// own engine for an action that shows no UI. Overridden in bootstrap with
/// the action handler's entry point; null leaves those actions unwired.

final class NotificationBackgroundEntryPointProvider
    extends
        $FunctionalProvider<
          DidReceiveBackgroundNotificationResponseCallback?,
          DidReceiveBackgroundNotificationResponseCallback?,
          DidReceiveBackgroundNotificationResponseCallback?
        >
    with $Provider<DidReceiveBackgroundNotificationResponseCallback?> {
  /// The top-level `@pragma('vm:entry-point')` function the plugin runs in its
  /// own engine for an action that shows no UI. Overridden in bootstrap with
  /// the action handler's entry point; null leaves those actions unwired.
  NotificationBackgroundEntryPointProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationBackgroundEntryPointProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationBackgroundEntryPointHash();

  @$internal
  @override
  $ProviderElement<DidReceiveBackgroundNotificationResponseCallback?>
  $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  DidReceiveBackgroundNotificationResponseCallback? create(Ref ref) {
    return notificationBackgroundEntryPoint(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(
    DidReceiveBackgroundNotificationResponseCallback? value,
  ) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<DidReceiveBackgroundNotificationResponseCallback?>(
            value,
          ),
    );
  }
}

String _$notificationBackgroundEntryPointHash() =>
    r'a4d83ba3fcdfb88d933d4c0eaaeac8374e0aa05e';

/// Taps, and actions that show the app, reported while the app runs. The
/// tap listener subscribes here; the tap that launched the app comes from
/// [notificationLaunchResponseProvider].

@ProviderFor(notificationResponses)
final notificationResponsesProvider = NotificationResponsesProvider._();

/// Taps, and actions that show the app, reported while the app runs. The
/// tap listener subscribes here; the tap that launched the app comes from
/// [notificationLaunchResponseProvider].

final class NotificationResponsesProvider
    extends
        $FunctionalProvider<
          NotificationResponses,
          NotificationResponses,
          NotificationResponses
        >
    with $Provider<NotificationResponses> {
  /// Taps, and actions that show the app, reported while the app runs. The
  /// tap listener subscribes here; the tap that launched the app comes from
  /// [notificationLaunchResponseProvider].
  NotificationResponsesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationResponsesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationResponsesHash();

  @$internal
  @override
  $ProviderElement<NotificationResponses> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationResponses create(Ref ref) {
    return notificationResponses(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationResponses value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationResponses>(value),
    );
  }
}

String _$notificationResponsesHash() =>
    r'316a78787aea935fec9758fbe0cd82d66c06b08d';

@ProviderFor(notificationLaunchResponse)
final notificationLaunchResponseProvider =
    NotificationLaunchResponseProvider._();

final class NotificationLaunchResponseProvider
    extends
        $FunctionalProvider<
          AsyncValue<NotificationResponse?>,
          NotificationResponse?,
          FutureOr<NotificationResponse?>
        >
    with
        $FutureModifier<NotificationResponse?>,
        $FutureProvider<NotificationResponse?> {
  NotificationLaunchResponseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationLaunchResponseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationLaunchResponseHash();

  @$internal
  @override
  $FutureProviderElement<NotificationResponse?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<NotificationResponse?> create(Ref ref) {
    return notificationLaunchResponse(ref);
  }
}

String _$notificationLaunchResponseHash() =>
    r'f8e2ea0aa493c9ea2eabedd4c989cde44e492bda';

/// The app's strings for the notification texts, without a widget tree.
/// Bootstrap and the background entry point override this with what
/// [loadDeviceAppLocalizations] resolved; the default serves the tests.

@ProviderFor(deviceAppLocalizations)
final deviceAppLocalizationsProvider = DeviceAppLocalizationsProvider._();

/// The app's strings for the notification texts, without a widget tree.
/// Bootstrap and the background entry point override this with what
/// [loadDeviceAppLocalizations] resolved; the default serves the tests.

final class DeviceAppLocalizationsProvider
    extends
        $FunctionalProvider<
          AppLocalizations,
          AppLocalizations,
          AppLocalizations
        >
    with $Provider<AppLocalizations> {
  /// The app's strings for the notification texts, without a widget tree.
  /// Bootstrap and the background entry point override this with what
  /// [loadDeviceAppLocalizations] resolved; the default serves the tests.
  DeviceAppLocalizationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceAppLocalizationsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceAppLocalizationsHash();

  @$internal
  @override
  $ProviderElement<AppLocalizations> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppLocalizations create(Ref ref) {
    return deviceAppLocalizations(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppLocalizations value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppLocalizations>(value),
    );
  }
}

String _$deviceAppLocalizationsHash() =>
    r'57a592750d5ac402099a562826af06fc9f0d41a3';
