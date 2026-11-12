// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_part.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appPart)
final appPartProvider = AppPartProvider._();

final class AppPartProvider
    extends $FunctionalProvider<AppPart, AppPart, AppPart>
    with $Provider<AppPart> {
  AppPartProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appPartProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appPartHash();

  @$internal
  @override
  $ProviderElement<AppPart> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppPart create(Ref ref) {
    return appPart(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppPart value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppPart>(value),
    );
  }
}

String _$appPartHash() => r'85eb90470f3b9e73b60fcd823a8560f93aea3ce7';
