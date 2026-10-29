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
    r'295c1a7ce19d50b21d9b4a05595a804c047e3852';

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

/// The app's strings for what the OS shows outside the widget tree:
/// notifications and their channels, widgets and the app lock prompt.
/// Bootstrap overrides the build with what [loadDeviceAppLocalizations]
/// resolved, and [deviceLanguageFollowerProvider] keeps it in the device's
/// language; the headless entry points override it with a value. The
/// default serves the tests.

@ProviderFor(DeviceAppLocalizations)
final deviceAppLocalizationsProvider = DeviceAppLocalizationsProvider._();

/// The app's strings for what the OS shows outside the widget tree:
/// notifications and their channels, widgets and the app lock prompt.
/// Bootstrap overrides the build with what [loadDeviceAppLocalizations]
/// resolved, and [deviceLanguageFollowerProvider] keeps it in the device's
/// language; the headless entry points override it with a value. The
/// default serves the tests.
final class DeviceAppLocalizationsProvider
    extends $NotifierProvider<DeviceAppLocalizations, AppLocalizations> {
  /// The app's strings for what the OS shows outside the widget tree:
  /// notifications and their channels, widgets and the app lock prompt.
  /// Bootstrap overrides the build with what [loadDeviceAppLocalizations]
  /// resolved, and [deviceLanguageFollowerProvider] keeps it in the device's
  /// language; the headless entry points override it with a value. The
  /// default serves the tests.
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
  DeviceAppLocalizations create() => DeviceAppLocalizations();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppLocalizations value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppLocalizations>(value),
    );
  }
}

String _$deviceAppLocalizationsHash() =>
    r'ce542f98bd466720dd0de28b82a40d081b060e01';

/// The app's strings for what the OS shows outside the widget tree:
/// notifications and their channels, widgets and the app lock prompt.
/// Bootstrap overrides the build with what [loadDeviceAppLocalizations]
/// resolved, and [deviceLanguageFollowerProvider] keeps it in the device's
/// language; the headless entry points override it with a value. The
/// default serves the tests.

abstract class _$DeviceAppLocalizations extends $Notifier<AppLocalizations> {
  AppLocalizations build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppLocalizations, AppLocalizations>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppLocalizations, AppLocalizations>,
              AppLocalizations,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// In the app: [deviceAppLocalizationsProvider] follows a change of the
/// device or per-app language while the app runs, which Android reports
/// without restarting the activity, and looks again on every resume. iOS
/// restarts the app instead. Bootstrap listens.

@ProviderFor(deviceLanguageFollower)
final deviceLanguageFollowerProvider = DeviceLanguageFollowerProvider._();

/// In the app: [deviceAppLocalizationsProvider] follows a change of the
/// device or per-app language while the app runs, which Android reports
/// without restarting the activity, and looks again on every resume. iOS
/// restarts the app instead. Bootstrap listens.

final class DeviceLanguageFollowerProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// In the app: [deviceAppLocalizationsProvider] follows a change of the
  /// device or per-app language while the app runs, which Android reports
  /// without restarting the activity, and looks again on every resume. iOS
  /// restarts the app instead. Bootstrap listens.
  DeviceLanguageFollowerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceLanguageFollowerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceLanguageFollowerHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return deviceLanguageFollower(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$deviceLanguageFollowerHash() =>
    r'd5884a23e67440d90cd1333dd969b76d39a90be2';
