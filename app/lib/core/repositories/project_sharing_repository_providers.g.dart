// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_sharing_repository_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(projectSharingRepositoryFor)
final projectSharingRepositoryForProvider =
    ProjectSharingRepositoryForFamily._();

final class ProjectSharingRepositoryForProvider
    extends
        $FunctionalProvider<
          ProjectSharingRepository,
          ProjectSharingRepository,
          ProjectSharingRepository
        >
    with $Provider<ProjectSharingRepository> {
  ProjectSharingRepositoryForProvider._({
    required ProjectSharingRepositoryForFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'projectSharingRepositoryForProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$projectSharingRepositoryForHash();

  @override
  String toString() {
    return r'projectSharingRepositoryForProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<ProjectSharingRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProjectSharingRepository create(Ref ref) {
    final argument = this.argument as String;
    return projectSharingRepositoryFor(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProjectSharingRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProjectSharingRepository>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ProjectSharingRepositoryForProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$projectSharingRepositoryForHash() =>
    r'6deb9c6e96a03c5a7a53d3105f862480bdc9cfae';

final class ProjectSharingRepositoryForFamily extends $Family
    with $FunctionalFamilyOverride<ProjectSharingRepository, String> {
  ProjectSharingRepositoryForFamily._()
    : super(
        retry: null,
        name: r'projectSharingRepositoryForProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ProjectSharingRepositoryForProvider call(String accountId) =>
      ProjectSharingRepositoryForProvider._(argument: accountId, from: this);

  @override
  String toString() => r'projectSharingRepositoryForProvider';
}

/// The active account's; null while nobody is signed in.

@ProviderFor(projectSharingRepository)
final projectSharingRepositoryProvider = ProjectSharingRepositoryProvider._();

/// The active account's; null while nobody is signed in.

final class ProjectSharingRepositoryProvider
    extends
        $FunctionalProvider<
          ProjectSharingRepository?,
          ProjectSharingRepository?,
          ProjectSharingRepository?
        >
    with $Provider<ProjectSharingRepository?> {
  /// The active account's; null while nobody is signed in.
  ProjectSharingRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectSharingRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectSharingRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProjectSharingRepository?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProjectSharingRepository? create(Ref ref) {
    return projectSharingRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProjectSharingRepository? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProjectSharingRepository?>(value),
    );
  }
}

String _$projectSharingRepositoryHash() =>
    r'25fc49458392a407c3bee968be8540cd45a585d3';
