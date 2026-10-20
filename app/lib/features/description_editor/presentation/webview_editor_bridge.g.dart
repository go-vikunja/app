// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'webview_editor_bridge.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(editorBridgeFactory)
final editorBridgeFactoryProvider = EditorBridgeFactoryProvider._();

final class EditorBridgeFactoryProvider
    extends
        $FunctionalProvider<
          EditorBridgeFactory,
          EditorBridgeFactory,
          EditorBridgeFactory
        >
    with $Provider<EditorBridgeFactory> {
  EditorBridgeFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'editorBridgeFactoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$editorBridgeFactoryHash();

  @$internal
  @override
  $ProviderElement<EditorBridgeFactory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EditorBridgeFactory create(Ref ref) {
    return editorBridgeFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EditorBridgeFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EditorBridgeFactory>(value),
    );
  }
}

String _$editorBridgeFactoryHash() =>
    r'df7f0b3e04d9c62435d97a1b47a29ac716a23e3a';
