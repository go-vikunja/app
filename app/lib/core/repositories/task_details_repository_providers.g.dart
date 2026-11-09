// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_details_repository_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(accountTaskDetailsRepository)
final accountTaskDetailsRepositoryProvider =
    AccountTaskDetailsRepositoryFamily._();

final class AccountTaskDetailsRepositoryProvider
    extends
        $FunctionalProvider<
          TaskDetailsRepository,
          TaskDetailsRepository,
          TaskDetailsRepository
        >
    with $Provider<TaskDetailsRepository> {
  AccountTaskDetailsRepositoryProvider._({
    required AccountTaskDetailsRepositoryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountTaskDetailsRepositoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountTaskDetailsRepositoryHash();

  @override
  String toString() {
    return r'accountTaskDetailsRepositoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<TaskDetailsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TaskDetailsRepository create(Ref ref) {
    final argument = this.argument as String;
    return accountTaskDetailsRepository(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaskDetailsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaskDetailsRepository>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountTaskDetailsRepositoryProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountTaskDetailsRepositoryHash() =>
    r'ce46862345cd9883f8f3e2cef156a2e5a32640c7';

final class AccountTaskDetailsRepositoryFamily extends $Family
    with $FunctionalFamilyOverride<TaskDetailsRepository, String> {
  AccountTaskDetailsRepositoryFamily._()
    : super(
        retry: null,
        name: r'accountTaskDetailsRepositoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountTaskDetailsRepositoryProvider call(String accountId) =>
      AccountTaskDetailsRepositoryProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountTaskDetailsRepositoryProvider';
}

/// The active account's; null while nobody is signed in.

@ProviderFor(taskDetailsRepository)
final taskDetailsRepositoryProvider = TaskDetailsRepositoryProvider._();

/// The active account's; null while nobody is signed in.

final class TaskDetailsRepositoryProvider
    extends
        $FunctionalProvider<
          TaskDetailsRepository?,
          TaskDetailsRepository?,
          TaskDetailsRepository?
        >
    with $Provider<TaskDetailsRepository?> {
  /// The active account's; null while nobody is signed in.
  TaskDetailsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taskDetailsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taskDetailsRepositoryHash();

  @$internal
  @override
  $ProviderElement<TaskDetailsRepository?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TaskDetailsRepository? create(Ref ref) {
    return taskDetailsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaskDetailsRepository? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaskDetailsRepository?>(value),
    );
  }
}

String _$taskDetailsRepositoryHash() =>
    r'a14daa759788a442a08ea89e5e920944b027dbd2';
