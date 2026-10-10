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

@ProviderFor(projectById)
final projectByIdProvider = ProjectByIdFamily._();

final class ProjectByIdProvider
    extends $FunctionalProvider<Project?, Project?, Project?>
    with $Provider<Project?> {
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

  ProjectByIdProvider call(int id) =>
      ProjectByIdProvider._(argument: id, from: this);

  @override
  String toString() => r'projectByIdProvider';
}

@ProviderFor(projectTasks)
final projectTasksProvider = ProjectTasksFamily._();

final class ProjectTasksProvider
    extends
        $FunctionalProvider<
          AsyncValue<PagedList<Task>>,
          PagedList<Task>,
          Stream<PagedList<Task>>
        >
    with $FutureModifier<PagedList<Task>>, $StreamProvider<PagedList<Task>> {
  ProjectTasksProvider._({
    required ProjectTasksFamily super.from,
    required (int, {bool showDone}) super.argument,
  }) : super(
         retry: null,
         name: r'projectTasksProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$projectTasksHash();

  @override
  String toString() {
    return r'projectTasksProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<PagedList<Task>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<PagedList<Task>> create(Ref ref) {
    final argument = this.argument as (int, {bool showDone});
    return projectTasks(ref, argument.$1, showDone: argument.showDone);
  }

  @override
  bool operator ==(Object other) {
    return other is ProjectTasksProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$projectTasksHash() => r'5953790a9155663d4213b82079c98d99fdad5150';

final class ProjectTasksFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<PagedList<Task>>,
          (int, {bool showDone})
        > {
  ProjectTasksFamily._()
    : super(
        retry: null,
        name: r'projectTasksProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ProjectTasksProvider call(int projectId, {required bool showDone}) =>
      ProjectTasksProvider._(
        argument: (projectId, showDone: showDone),
        from: this,
      );

  @override
  String toString() => r'projectTasksProvider';
}
