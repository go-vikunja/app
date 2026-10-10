// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'repository_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(activeAccountId)
final activeAccountIdProvider = ActiveAccountIdProvider._();

final class ActiveAccountIdProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  ActiveAccountIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeAccountIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeAccountIdHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return activeAccountId(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$activeAccountIdHash() => r'07a5feac1a80c62c1728f98bba9dcebb1446c138';

/// Reads for one account, through its session manager. Kept alive by the
/// repositories that use it, so it goes with them on sign-out.

@ProviderFor(readClient)
final readClientProvider = ReadClientFamily._();

/// Reads for one account, through its session manager. Kept alive by the
/// repositories that use it, so it goes with them on sign-out.

final class ReadClientProvider
    extends
        $FunctionalProvider<
          VikunjaReadClient,
          VikunjaReadClient,
          VikunjaReadClient
        >
    with $Provider<VikunjaReadClient> {
  /// Reads for one account, through its session manager. Kept alive by the
  /// repositories that use it, so it goes with them on sign-out.
  ReadClientProvider._({
    required ReadClientFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'readClientProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$readClientHash();

  @override
  String toString() {
    return r'readClientProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<VikunjaReadClient> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VikunjaReadClient create(Ref ref) {
    final argument = this.argument as String;
    return readClient(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VikunjaReadClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VikunjaReadClient>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ReadClientProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$readClientHash() => r'3ad409139f33c1caeedfdc3679744b3581f9a56a';

/// Reads for one account, through its session manager. Kept alive by the
/// repositories that use it, so it goes with them on sign-out.

final class ReadClientFamily extends $Family
    with $FunctionalFamilyOverride<VikunjaReadClient, String> {
  ReadClientFamily._()
    : super(
        retry: null,
        name: r'readClientProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Reads for one account, through its session manager. Kept alive by the
  /// repositories that use it, so it goes with them on sign-out.

  ReadClientProvider call(String accountId) =>
      ReadClientProvider._(argument: accountId, from: this);

  @override
  String toString() => r'readClientProvider';
}

/// The active account's projects; rebuilt, and the old one disposed, when
/// the active account changes. Null while no account is signed in.

@ProviderFor(projectRepository)
final projectRepositoryProvider = ProjectRepositoryProvider._();

/// The active account's projects; rebuilt, and the old one disposed, when
/// the active account changes. Null while no account is signed in.

final class ProjectRepositoryProvider
    extends
        $FunctionalProvider<
          ProjectRepository?,
          ProjectRepository?,
          ProjectRepository?
        >
    with $Provider<ProjectRepository?> {
  /// The active account's projects; rebuilt, and the old one disposed, when
  /// the active account changes. Null while no account is signed in.
  ProjectRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProjectRepository?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProjectRepository? create(Ref ref) {
    return projectRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProjectRepository? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProjectRepository?>(value),
    );
  }
}

String _$projectRepositoryHash() => r'1692aafed99ff333566e0f91146b2417b3fd1d76';

@ProviderFor(taskRepository)
final taskRepositoryProvider = TaskRepositoryProvider._();

final class TaskRepositoryProvider
    extends
        $FunctionalProvider<TaskRepository?, TaskRepository?, TaskRepository?>
    with $Provider<TaskRepository?> {
  TaskRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taskRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taskRepositoryHash();

  @$internal
  @override
  $ProviderElement<TaskRepository?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TaskRepository? create(Ref ref) {
    return taskRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaskRepository? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaskRepository?>(value),
    );
  }
}

String _$taskRepositoryHash() => r'e09104fab6491912e7bdf76fe8b4ca25522dd51f';
