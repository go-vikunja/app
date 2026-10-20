// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_search_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(accountTaskSearch)
final accountTaskSearchProvider = AccountTaskSearchFamily._();

final class AccountTaskSearchProvider
    extends $FunctionalProvider<TaskSearch, TaskSearch, TaskSearch>
    with $Provider<TaskSearch> {
  AccountTaskSearchProvider._({
    required AccountTaskSearchFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountTaskSearchProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountTaskSearchHash();

  @override
  String toString() {
    return r'accountTaskSearchProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<TaskSearch> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TaskSearch create(Ref ref) {
    final argument = this.argument as String;
    return accountTaskSearch(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaskSearch value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaskSearch>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountTaskSearchProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountTaskSearchHash() => r'2b18fff31d8121778a916e78cec255ea675d9d0a';

final class AccountTaskSearchFamily extends $Family
    with $FunctionalFamilyOverride<TaskSearch, String> {
  AccountTaskSearchFamily._()
    : super(
        retry: null,
        name: r'accountTaskSearchProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountTaskSearchProvider call(String accountId) =>
      AccountTaskSearchProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountTaskSearchProvider';
}

/// The active account's; null while nobody is signed in.

@ProviderFor(taskSearch)
final taskSearchProvider = TaskSearchProvider._();

/// The active account's; null while nobody is signed in.

final class TaskSearchProvider
    extends $FunctionalProvider<TaskSearch?, TaskSearch?, TaskSearch?>
    with $Provider<TaskSearch?> {
  /// The active account's; null while nobody is signed in.
  TaskSearchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taskSearchProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taskSearchHash();

  @$internal
  @override
  $ProviderElement<TaskSearch?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TaskSearch? create(Ref ref) {
    return taskSearch(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaskSearch? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaskSearch?>(value),
    );
  }
}

String _$taskSearchHash() => r'e6359677e24d1f7462fd1ff62375484ba9f711ef';
