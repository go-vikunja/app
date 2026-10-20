// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_view_repository_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(accountProjectViewRepository)
final accountProjectViewRepositoryProvider =
    AccountProjectViewRepositoryFamily._();

final class AccountProjectViewRepositoryProvider
    extends
        $FunctionalProvider<
          ProjectViewRepository,
          ProjectViewRepository,
          ProjectViewRepository
        >
    with $Provider<ProjectViewRepository> {
  AccountProjectViewRepositoryProvider._({
    required AccountProjectViewRepositoryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountProjectViewRepositoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountProjectViewRepositoryHash();

  @override
  String toString() {
    return r'accountProjectViewRepositoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<ProjectViewRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProjectViewRepository create(Ref ref) {
    final argument = this.argument as String;
    return accountProjectViewRepository(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProjectViewRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProjectViewRepository>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountProjectViewRepositoryProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountProjectViewRepositoryHash() =>
    r'8630ef3095365049f005135de0b0df62c80d63ce';

final class AccountProjectViewRepositoryFamily extends $Family
    with $FunctionalFamilyOverride<ProjectViewRepository, String> {
  AccountProjectViewRepositoryFamily._()
    : super(
        retry: null,
        name: r'accountProjectViewRepositoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountProjectViewRepositoryProvider call(String accountId) =>
      AccountProjectViewRepositoryProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountProjectViewRepositoryProvider';
}

/// The active account's; null while nobody is signed in.

@ProviderFor(projectViewRepository)
final projectViewRepositoryProvider = ProjectViewRepositoryProvider._();

/// The active account's; null while nobody is signed in.

final class ProjectViewRepositoryProvider
    extends
        $FunctionalProvider<
          ProjectViewRepository?,
          ProjectViewRepository?,
          ProjectViewRepository?
        >
    with $Provider<ProjectViewRepository?> {
  /// The active account's; null while nobody is signed in.
  ProjectViewRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectViewRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectViewRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProjectViewRepository?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProjectViewRepository? create(Ref ref) {
    return projectViewRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProjectViewRepository? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProjectViewRepository?>(value),
    );
  }
}

String _$projectViewRepositoryHash() =>
    r'9afe0133469bfedb50e5e7f8ef4810edee65392a';
