// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sensitive_clipboard.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(sensitiveClipboard)
final sensitiveClipboardProvider = SensitiveClipboardProvider._();

final class SensitiveClipboardProvider
    extends
        $FunctionalProvider<
          SensitiveClipboard,
          SensitiveClipboard,
          SensitiveClipboard
        >
    with $Provider<SensitiveClipboard> {
  SensitiveClipboardProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sensitiveClipboardProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sensitiveClipboardHash();

  @$internal
  @override
  $ProviderElement<SensitiveClipboard> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SensitiveClipboard create(Ref ref) {
    return sensitiveClipboard(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SensitiveClipboard value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SensitiveClipboard>(value),
    );
  }
}

String _$sensitiveClipboardHash() =>
    r'8a2b3b3ea66f04e76afc48810576604a6ae4f8ec';
