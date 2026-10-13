// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'background_last_run.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// When the background sync last ran for [accountId]; null before its
/// first run. Another isolate writes it, so it is read again every minute
/// while the app is in front and when it comes back.

@ProviderFor(backgroundLastRun)
final backgroundLastRunProvider = BackgroundLastRunFamily._();

/// When the background sync last ran for [accountId]; null before its
/// first run. Another isolate writes it, so it is read again every minute
/// while the app is in front and when it comes back.

final class BackgroundLastRunProvider
    extends
        $FunctionalProvider<
          AsyncValue<DateTime?>,
          DateTime?,
          FutureOr<DateTime?>
        >
    with $FutureModifier<DateTime?>, $FutureProvider<DateTime?> {
  /// When the background sync last ran for [accountId]; null before its
  /// first run. Another isolate writes it, so it is read again every minute
  /// while the app is in front and when it comes back.
  BackgroundLastRunProvider._({
    required BackgroundLastRunFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'backgroundLastRunProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$backgroundLastRunHash();

  @override
  String toString() {
    return r'backgroundLastRunProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<DateTime?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<DateTime?> create(Ref ref) {
    final argument = this.argument as String;
    return backgroundLastRun(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BackgroundLastRunProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$backgroundLastRunHash() => r'fbdcde012ca8c0c729370f9b9e103f46de070cb7';

/// When the background sync last ran for [accountId]; null before its
/// first run. Another isolate writes it, so it is read again every minute
/// while the app is in front and when it comes back.

final class BackgroundLastRunFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<DateTime?>, String> {
  BackgroundLastRunFamily._()
    : super(
        retry: null,
        name: r'backgroundLastRunProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// When the background sync last ran for [accountId]; null before its
  /// first run. Another isolate writes it, so it is read again every minute
  /// while the app is in front and when it comes back.

  BackgroundLastRunProvider call(String accountId) =>
      BackgroundLastRunProvider._(argument: accountId, from: this);

  @override
  String toString() => r'backgroundLastRunProvider';
}
