// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_access.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The stored project's access, following each sync; [ProjectAccess.unknown]
/// while the project is not stored (or nobody is signed in).

@ProviderFor(projectAccess)
final projectAccessProvider = ProjectAccessFamily._();

/// The stored project's access, following each sync; [ProjectAccess.unknown]
/// while the project is not stored (or nobody is signed in).

final class ProjectAccessProvider
    extends $FunctionalProvider<ProjectAccess, ProjectAccess, ProjectAccess>
    with $Provider<ProjectAccess> {
  /// The stored project's access, following each sync; [ProjectAccess.unknown]
  /// while the project is not stored (or nobody is signed in).
  ProjectAccessProvider._({
    required ProjectAccessFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'projectAccessProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$projectAccessHash();

  @override
  String toString() {
    return r'projectAccessProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<ProjectAccess> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ProjectAccess create(Ref ref) {
    final argument = this.argument as int;
    return projectAccess(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProjectAccess value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProjectAccess>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ProjectAccessProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$projectAccessHash() => r'f22891e066eaff889aabf344aac20ca8a28c20c4';

/// The stored project's access, following each sync; [ProjectAccess.unknown]
/// while the project is not stored (or nobody is signed in).

final class ProjectAccessFamily extends $Family
    with $FunctionalFamilyOverride<ProjectAccess, int> {
  ProjectAccessFamily._()
    : super(
        retry: null,
        name: r'projectAccessProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The stored project's access, following each sync; [ProjectAccess.unknown]
  /// while the project is not stored (or nobody is signed in).

  ProjectAccessProvider call(int projectId) =>
      ProjectAccessProvider._(argument: projectId, from: this);

  @override
  String toString() => r'projectAccessProvider';
}
