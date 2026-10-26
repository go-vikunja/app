// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_repository_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(teamRepositoryFor)
final teamRepositoryForProvider = TeamRepositoryForFamily._();

final class TeamRepositoryForProvider
    extends $FunctionalProvider<TeamRepository, TeamRepository, TeamRepository>
    with $Provider<TeamRepository> {
  TeamRepositoryForProvider._({
    required TeamRepositoryForFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'teamRepositoryForProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$teamRepositoryForHash();

  @override
  String toString() {
    return r'teamRepositoryForProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<TeamRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TeamRepository create(Ref ref) {
    final argument = this.argument as String;
    return teamRepositoryFor(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TeamRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TeamRepository>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TeamRepositoryForProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$teamRepositoryForHash() => r'bbbbc625ce140c5f9a06fa6138dd9ba27b7d19f5';

final class TeamRepositoryForFamily extends $Family
    with $FunctionalFamilyOverride<TeamRepository, String> {
  TeamRepositoryForFamily._()
    : super(
        retry: null,
        name: r'teamRepositoryForProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TeamRepositoryForProvider call(String accountId) =>
      TeamRepositoryForProvider._(argument: accountId, from: this);

  @override
  String toString() => r'teamRepositoryForProvider';
}

/// The active account's; null while nobody is signed in.

@ProviderFor(teamRepository)
final teamRepositoryProvider = TeamRepositoryProvider._();

/// The active account's; null while nobody is signed in.

final class TeamRepositoryProvider
    extends
        $FunctionalProvider<TeamRepository?, TeamRepository?, TeamRepository?>
    with $Provider<TeamRepository?> {
  /// The active account's; null while nobody is signed in.
  TeamRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'teamRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$teamRepositoryHash();

  @$internal
  @override
  $ProviderElement<TeamRepository?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TeamRepository? create(Ref ref) {
    return teamRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TeamRepository? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TeamRepository?>(value),
    );
  }
}

String _$teamRepositoryHash() => r'9fbaf8788e7a457ec3753c7e4a33d50ddf99ac12';
