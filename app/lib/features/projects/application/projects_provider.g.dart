// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'projects_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Stays loading while no account is signed in.

@ProviderFor(projects)
final projectsProvider = ProjectsProvider._();

/// Stays loading while no account is signed in.

final class ProjectsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Project>>,
          List<Project>,
          Stream<List<Project>>
        >
    with $FutureModifier<List<Project>>, $StreamProvider<List<Project>> {
  /// Stays loading while no account is signed in.
  ProjectsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectsHash();

  @$internal
  @override
  $StreamProviderElement<List<Project>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Project>> create(Ref ref) {
    return projects(ref);
  }
}

String _$projectsHash() => r'4d4dcdc6f5d47bbcb899f0078c1c3a3b41d4e2d3';

/// Leaves out a change of the project's views alone (`Project ==` ignores
/// them); read the views from [projectsProvider].

@ProviderFor(projectById)
final projectByIdProvider = ProjectByIdFamily._();

/// Leaves out a change of the project's views alone (`Project ==` ignores
/// them); read the views from [projectsProvider].

final class ProjectByIdProvider
    extends $FunctionalProvider<Project?, Project?, Project?>
    with $Provider<Project?> {
  /// Leaves out a change of the project's views alone (`Project ==` ignores
  /// them); read the views from [projectsProvider].
  ProjectByIdProvider._({
    required ProjectByIdFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'projectByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$projectByIdHash();

  @override
  String toString() {
    return r'projectByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<Project?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Project? create(Ref ref) {
    final argument = this.argument as int;
    return projectById(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Project? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Project?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ProjectByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$projectByIdHash() => r'4a521960f41ee2afd73dbd9cd1855b608ef400e9';

/// Leaves out a change of the project's views alone (`Project ==` ignores
/// them); read the views from [projectsProvider].

final class ProjectByIdFamily extends $Family
    with $FunctionalFamilyOverride<Project?, int> {
  ProjectByIdFamily._()
    : super(
        retry: null,
        name: r'projectByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Leaves out a change of the project's views alone (`Project ==` ignores
  /// them); read the views from [projectsProvider].

  ProjectByIdProvider call(int id) =>
      ProjectByIdProvider._(argument: id, from: this);

  @override
  String toString() => r'projectByIdProvider';
}

/// Stays loading while no account is signed in. [includeDone] as in
/// `TaskRepository.watchProjectList`.

@ProviderFor(projectListSource)
final projectListSourceProvider = ProjectListSourceFamily._();

/// Stays loading while no account is signed in. [includeDone] as in
/// `TaskRepository.watchProjectList`.

final class ProjectListSourceProvider
    extends
        $FunctionalProvider<
          AsyncValue<ProjectListSource>,
          ProjectListSource,
          Stream<ProjectListSource>
        >
    with
        $FutureModifier<ProjectListSource>,
        $StreamProvider<ProjectListSource> {
  /// Stays loading while no account is signed in. [includeDone] as in
  /// `TaskRepository.watchProjectList`.
  ProjectListSourceProvider._({
    required ProjectListSourceFamily super.from,
    required (int, {int viewId, bool includeDone}) super.argument,
  }) : super(
         retry: null,
         name: r'projectListSourceProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$projectListSourceHash();

  @override
  String toString() {
    return r'projectListSourceProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<ProjectListSource> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<ProjectListSource> create(Ref ref) {
    final argument = this.argument as (int, {int viewId, bool includeDone});
    return projectListSource(
      ref,
      argument.$1,
      viewId: argument.viewId,
      includeDone: argument.includeDone,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ProjectListSourceProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$projectListSourceHash() => r'1ddbf42a7399d946f9a7b70c83a8c40a44af2813';

/// Stays loading while no account is signed in. [includeDone] as in
/// `TaskRepository.watchProjectList`.

final class ProjectListSourceFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<ProjectListSource>,
          (int, {int viewId, bool includeDone})
        > {
  ProjectListSourceFamily._()
    : super(
        retry: null,
        name: r'projectListSourceProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Stays loading while no account is signed in. [includeDone] as in
  /// `TaskRepository.watchProjectList`.

  ProjectListSourceProvider call(
    int projectId, {
    required int viewId,
    required bool includeDone,
  }) => ProjectListSourceProvider._(
    argument: (projectId, viewId: viewId, includeDone: includeDone),
    from: this,
  );

  @override
  String toString() => r'projectListSourceProvider';
}

/// [listKey] from `listKeyFor`; the defaults while nobody is signed in.

@ProviderFor(viewPreferences)
final viewPreferencesProvider = ViewPreferencesFamily._();

/// [listKey] from `listKeyFor`; the defaults while nobody is signed in.

final class ViewPreferencesProvider
    extends
        $FunctionalProvider<
          AsyncValue<ViewPreferences>,
          ViewPreferences,
          Stream<ViewPreferences>
        >
    with $FutureModifier<ViewPreferences>, $StreamProvider<ViewPreferences> {
  /// [listKey] from `listKeyFor`; the defaults while nobody is signed in.
  ViewPreferencesProvider._({
    required ViewPreferencesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'viewPreferencesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$viewPreferencesHash();

  @override
  String toString() {
    return r'viewPreferencesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<ViewPreferences> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<ViewPreferences> create(Ref ref) {
    final argument = this.argument as String;
    return viewPreferences(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ViewPreferencesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$viewPreferencesHash() => r'76c06654cc7099430c9e197b89b66bff0ba54acf';

/// [listKey] from `listKeyFor`; the defaults while nobody is signed in.

final class ViewPreferencesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<ViewPreferences>, String> {
  ViewPreferencesFamily._()
    : super(
        retry: null,
        name: r'viewPreferencesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// [listKey] from `listKeyFor`; the defaults while nobody is signed in.

  ViewPreferencesProvider call(String listKey) =>
      ViewPreferencesProvider._(argument: listKey, from: this);

  @override
  String toString() => r'viewPreferencesProvider';
}
