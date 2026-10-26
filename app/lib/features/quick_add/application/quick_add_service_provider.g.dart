// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quick_add_service_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The active account's quick add; null while nobody is signed in. Rebuilt
/// whenever the projects, labels, known people or settings it plans with
/// change, so a watcher plans again.

@ProviderFor(quickAddService)
final quickAddServiceProvider = QuickAddServiceProvider._();

/// The active account's quick add; null while nobody is signed in. Rebuilt
/// whenever the projects, labels, known people or settings it plans with
/// change, so a watcher plans again.

final class QuickAddServiceProvider
    extends
        $FunctionalProvider<
          QuickAddService?,
          QuickAddService?,
          QuickAddService?
        >
    with $Provider<QuickAddService?> {
  /// The active account's quick add; null while nobody is signed in. Rebuilt
  /// whenever the projects, labels, known people or settings it plans with
  /// change, so a watcher plans again.
  QuickAddServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'quickAddServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$quickAddServiceHash();

  @$internal
  @override
  $ProviderElement<QuickAddService?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  QuickAddService? create(Ref ref) {
    return quickAddService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(QuickAddService? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<QuickAddService?>(value),
    );
  }
}

String _$quickAddServiceHash() => r'21b5d5e486c1a340d80f37ffc1309b3f7ea57f8e';
