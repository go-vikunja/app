// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_shortcuts.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appShortcuts)
final appShortcutsProvider = AppShortcutsProvider._();

final class AppShortcutsProvider
    extends $FunctionalProvider<AppShortcuts, AppShortcuts, AppShortcuts>
    with $Provider<AppShortcuts> {
  AppShortcutsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appShortcutsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appShortcutsHash();

  @$internal
  @override
  $ProviderElement<AppShortcuts> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppShortcuts create(Ref ref) {
    return appShortcuts(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppShortcuts value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppShortcuts>(value),
    );
  }
}

String _$appShortcutsHash() => r'2f5cd2df7c6fa737a0691b94c44013d36c1eed61';
