// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$projectControllerHash() => r'08ba8e8264c1ea14ad842ee1807055b3f051f702';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$ProjectController
    extends BuildlessAutoDisposeAsyncNotifier<ProjectPageModel> {
  late final Project project;

  FutureOr<ProjectPageModel> build(Project project);
}

/// See also [ProjectController].
@ProviderFor(ProjectController)
const projectControllerProvider = ProjectControllerFamily();

/// See also [ProjectController].
class ProjectControllerFamily extends Family<AsyncValue<ProjectPageModel>> {
  /// See also [ProjectController].
  const ProjectControllerFamily();

  /// See also [ProjectController].
  ProjectControllerProvider call(Project project) {
    return ProjectControllerProvider(project);
  }

  @override
  ProjectControllerProvider getProviderOverride(
    covariant ProjectControllerProvider provider,
  ) {
    return call(provider.project);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'projectControllerProvider';
}

/// See also [ProjectController].
class ProjectControllerProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<
          ProjectController,
          ProjectPageModel
        > {
  /// See also [ProjectController].
  ProjectControllerProvider(Project project)
    : this._internal(
        () => ProjectController()..project = project,
        from: projectControllerProvider,
        name: r'projectControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$projectControllerHash,
        dependencies: ProjectControllerFamily._dependencies,
        allTransitiveDependencies:
            ProjectControllerFamily._allTransitiveDependencies,
        project: project,
      );

  ProjectControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.project,
  }) : super.internal();

  final Project project;

  @override
  FutureOr<ProjectPageModel> runNotifierBuild(
    covariant ProjectController notifier,
  ) {
    return notifier.build(project);
  }

  @override
  Override overrideWith(ProjectController Function() create) {
    return ProviderOverride(
      origin: this,
      override: ProjectControllerProvider._internal(
        () => create()..project = project,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        project: project,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<ProjectController, ProjectPageModel>
  createElement() {
    return _ProjectControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ProjectControllerProvider && other.project == project;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, project.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ProjectControllerRef
    on AutoDisposeAsyncNotifierProviderRef<ProjectPageModel> {
  /// The parameter `project` of this provider.
  Project get project;
}

class _ProjectControllerProviderElement
    extends
        AutoDisposeAsyncNotifierProviderElement<
          ProjectController,
          ProjectPageModel
        >
    with ProjectControllerRef {
  _ProjectControllerProviderElement(super.provider);

  @override
  Project get project => (origin as ProjectControllerProvider).project;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
