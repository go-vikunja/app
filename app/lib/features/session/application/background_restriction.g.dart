// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'background_restriction.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Read when first watched and again whenever the app comes back to the
/// front, because the user changes it in the system settings.

@ProviderFor(BackgroundRestrictionState)
final backgroundRestrictionStateProvider =
    BackgroundRestrictionStateProvider._();

/// Read when first watched and again whenever the app comes back to the
/// front, because the user changes it in the system settings.
final class BackgroundRestrictionStateProvider
    extends
        $AsyncNotifierProvider<
          BackgroundRestrictionState,
          BackgroundRestriction?
        > {
  /// Read when first watched and again whenever the app comes back to the
  /// front, because the user changes it in the system settings.
  BackgroundRestrictionStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backgroundRestrictionStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backgroundRestrictionStateHash();

  @$internal
  @override
  BackgroundRestrictionState create() => BackgroundRestrictionState();
}

String _$backgroundRestrictionStateHash() =>
    r'e55ee2d962d40b98bd93c91f6d66cef441205ca3';

/// Read when first watched and again whenever the app comes back to the
/// front, because the user changes it in the system settings.

abstract class _$BackgroundRestrictionState
    extends $AsyncNotifier<BackgroundRestriction?> {
  FutureOr<BackgroundRestriction?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<BackgroundRestriction?>, BackgroundRestriction?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<BackgroundRestriction?>,
                BackgroundRestriction?
              >,
              AsyncValue<BackgroundRestriction?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
