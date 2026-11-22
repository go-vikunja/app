// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'background_sync_status.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Other isolates write all of it, so it is read again every minute while
/// the app is in front and when it comes back.

@ProviderFor(backgroundSyncStatus)
final backgroundSyncStatusProvider = BackgroundSyncStatusFamily._();

/// Other isolates write all of it, so it is read again every minute while
/// the app is in front and when it comes back.

final class BackgroundSyncStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<BackgroundSyncStatus>,
          BackgroundSyncStatus,
          FutureOr<BackgroundSyncStatus>
        >
    with
        $FutureModifier<BackgroundSyncStatus>,
        $FutureProvider<BackgroundSyncStatus> {
  /// Other isolates write all of it, so it is read again every minute while
  /// the app is in front and when it comes back.
  BackgroundSyncStatusProvider._({
    required BackgroundSyncStatusFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'backgroundSyncStatusProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$backgroundSyncStatusHash();

  @override
  String toString() {
    return r'backgroundSyncStatusProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<BackgroundSyncStatus> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BackgroundSyncStatus> create(Ref ref) {
    final argument = this.argument as String;
    return backgroundSyncStatus(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BackgroundSyncStatusProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$backgroundSyncStatusHash() =>
    r'6e420f1635fe725bc27dbc9f696c60086f78fcb6';

/// Other isolates write all of it, so it is read again every minute while
/// the app is in front and when it comes back.

final class BackgroundSyncStatusFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<BackgroundSyncStatus>, String> {
  BackgroundSyncStatusFamily._()
    : super(
        retry: null,
        name: r'backgroundSyncStatusProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Other isolates write all of it, so it is read again every minute while
  /// the app is in front and when it comes back.

  BackgroundSyncStatusProvider call(String accountId) =>
      BackgroundSyncStatusProvider._(argument: accountId, from: this);

  @override
  String toString() => r'backgroundSyncStatusProvider';
}

/// Read again whenever the account's sign-in mark flips, as an end is
/// recorded before the mark, and every minute for other isolates'
/// records. A value read before the mark tells nothing about its end.

@ProviderFor(markedSessionEnd)
final markedSessionEndProvider = MarkedSessionEndFamily._();

/// Read again whenever the account's sign-in mark flips, as an end is
/// recorded before the mark, and every minute for other isolates'
/// records. A value read before the mark tells nothing about its end.

final class MarkedSessionEndProvider
    extends
        $FunctionalProvider<
          AsyncValue<MarkedSessionEnd>,
          MarkedSessionEnd,
          FutureOr<MarkedSessionEnd>
        >
    with $FutureModifier<MarkedSessionEnd>, $FutureProvider<MarkedSessionEnd> {
  /// Read again whenever the account's sign-in mark flips, as an end is
  /// recorded before the mark, and every minute for other isolates'
  /// records. A value read before the mark tells nothing about its end.
  MarkedSessionEndProvider._({
    required MarkedSessionEndFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'markedSessionEndProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$markedSessionEndHash();

  @override
  String toString() {
    return r'markedSessionEndProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<MarkedSessionEnd> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MarkedSessionEnd> create(Ref ref) {
    final argument = this.argument as String;
    return markedSessionEnd(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MarkedSessionEndProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$markedSessionEndHash() => r'b94f62cbdd18f3055f79ca2d6de55ae830402a83';

/// Read again whenever the account's sign-in mark flips, as an end is
/// recorded before the mark, and every minute for other isolates'
/// records. A value read before the mark tells nothing about its end.

final class MarkedSessionEndFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<MarkedSessionEnd>, String> {
  MarkedSessionEndFamily._()
    : super(
        retry: null,
        name: r'markedSessionEndProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Read again whenever the account's sign-in mark flips, as an end is
  /// recorded before the mark, and every minute for other isolates'
  /// records. A value read before the mark tells nothing about its end.

  MarkedSessionEndProvider call(String accountId) =>
      MarkedSessionEndProvider._(argument: accountId, from: this);

  @override
  String toString() => r'markedSessionEndProvider';
}
