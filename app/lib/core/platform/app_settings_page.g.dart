// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings_page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appSettingsPage)
final appSettingsPageProvider = AppSettingsPageProvider._();

final class AppSettingsPageProvider
    extends
        $FunctionalProvider<AppSettingsPage, AppSettingsPage, AppSettingsPage>
    with $Provider<AppSettingsPage> {
  AppSettingsPageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appSettingsPageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appSettingsPageHash();

  @$internal
  @override
  $ProviderElement<AppSettingsPage> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppSettingsPage create(Ref ref) {
    return appSettingsPage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppSettingsPage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppSettingsPage>(value),
    );
  }
}

String _$appSettingsPageHash() => r'799418e3be067288ecf968822878013226556e85';
