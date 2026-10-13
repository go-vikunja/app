// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_repository_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(activityTray)
final activityTrayProvider = ActivityTrayProvider._();

final class ActivityTrayProvider
    extends $FunctionalProvider<ActivityTray, ActivityTray, ActivityTray>
    with $Provider<ActivityTray> {
  ActivityTrayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activityTrayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activityTrayHash();

  @$internal
  @override
  $ProviderElement<ActivityTray> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ActivityTray create(Ref ref) {
    return activityTray(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ActivityTray value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ActivityTray>(value),
    );
  }
}

String _$activityTrayHash() => r'7e709d6a0d4608aca04bfc2408b0e89a41729905';

/// One account's activity sync (the server's notifications); goes with its
/// database on sign-out.

@ProviderFor(activitySync)
final activitySyncProvider = ActivitySyncFamily._();

/// One account's activity sync (the server's notifications); goes with its
/// database on sign-out.

final class ActivitySyncProvider
    extends $FunctionalProvider<ActivitySync, ActivitySync, ActivitySync>
    with $Provider<ActivitySync> {
  /// One account's activity sync (the server's notifications); goes with its
  /// database on sign-out.
  ActivitySyncProvider._({
    required ActivitySyncFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'activitySyncProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$activitySyncHash();

  @override
  String toString() {
    return r'activitySyncProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<ActivitySync> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ActivitySync create(Ref ref) {
    final argument = this.argument as String;
    return activitySync(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ActivitySync value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ActivitySync>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ActivitySyncProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$activitySyncHash() => r'fd0942b6fef0e2e51757078ef05779253456ce49';

/// One account's activity sync (the server's notifications); goes with its
/// database on sign-out.

final class ActivitySyncFamily extends $Family
    with $FunctionalFamilyOverride<ActivitySync, String> {
  ActivitySyncFamily._()
    : super(
        retry: null,
        name: r'activitySyncProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// One account's activity sync (the server's notifications); goes with its
  /// database on sign-out.

  ActivitySyncProvider call(String accountId) =>
      ActivitySyncProvider._(argument: accountId, from: this);

  @override
  String toString() => r'activitySyncProvider';
}

/// Kept alive by [activityRepositoryProvider], so it goes when another
/// account takes over.

@ProviderFor(accountActivityRepository)
final accountActivityRepositoryProvider = AccountActivityRepositoryFamily._();

/// Kept alive by [activityRepositoryProvider], so it goes when another
/// account takes over.

final class AccountActivityRepositoryProvider
    extends
        $FunctionalProvider<
          ActivityRepository,
          ActivityRepository,
          ActivityRepository
        >
    with $Provider<ActivityRepository> {
  /// Kept alive by [activityRepositoryProvider], so it goes when another
  /// account takes over.
  AccountActivityRepositoryProvider._({
    required AccountActivityRepositoryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountActivityRepositoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountActivityRepositoryHash();

  @override
  String toString() {
    return r'accountActivityRepositoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<ActivityRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ActivityRepository create(Ref ref) {
    final argument = this.argument as String;
    return accountActivityRepository(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ActivityRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ActivityRepository>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountActivityRepositoryProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountActivityRepositoryHash() =>
    r'c8b9a9c7890d1d39de4522934f35d73d91c75cd2';

/// Kept alive by [activityRepositoryProvider], so it goes when another
/// account takes over.

final class AccountActivityRepositoryFamily extends $Family
    with $FunctionalFamilyOverride<ActivityRepository, String> {
  AccountActivityRepositoryFamily._()
    : super(
        retry: null,
        name: r'accountActivityRepositoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Kept alive by [activityRepositoryProvider], so it goes when another
  /// account takes over.

  AccountActivityRepositoryProvider call(String accountId) =>
      AccountActivityRepositoryProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountActivityRepositoryProvider';
}

/// The active account's inbox; null while nobody is signed in.

@ProviderFor(activityRepository)
final activityRepositoryProvider = ActivityRepositoryProvider._();

/// The active account's inbox; null while nobody is signed in.

final class ActivityRepositoryProvider
    extends
        $FunctionalProvider<
          ActivityRepository?,
          ActivityRepository?,
          ActivityRepository?
        >
    with $Provider<ActivityRepository?> {
  /// The active account's inbox; null while nobody is signed in.
  ActivityRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activityRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activityRepositoryHash();

  @$internal
  @override
  $ProviderElement<ActivityRepository?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ActivityRepository? create(Ref ref) {
    return activityRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ActivityRepository? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ActivityRepository?>(value),
    );
  }
}

String _$activityRepositoryHash() =>
    r'47d3af52b70d63dcdf7a1473b3256708fbfd4c31';
