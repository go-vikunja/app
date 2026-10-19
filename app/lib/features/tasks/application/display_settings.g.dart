// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'display_settings.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(displaySettings)
final displaySettingsProvider = DisplaySettingsProvider._();

final class DisplaySettingsProvider
    extends
        $FunctionalProvider<DisplaySettings, DisplaySettings, DisplaySettings>
    with $Provider<DisplaySettings> {
  DisplaySettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'displaySettingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$displaySettingsHash();

  @$internal
  @override
  $ProviderElement<DisplaySettings> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DisplaySettings create(Ref ref) {
    return displaySettings(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DisplaySettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DisplaySettings>(value),
    );
  }
}

String _$displaySettingsHash() => r'286de829f282b78c1904e64d55d03116eac1cf5f';
