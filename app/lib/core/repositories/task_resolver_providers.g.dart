// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_resolver_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(accountTaskResolver)
final accountTaskResolverProvider = AccountTaskResolverFamily._();

final class AccountTaskResolverProvider
    extends $FunctionalProvider<TaskResolver, TaskResolver, TaskResolver>
    with $Provider<TaskResolver> {
  AccountTaskResolverProvider._({
    required AccountTaskResolverFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountTaskResolverProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountTaskResolverHash();

  @override
  String toString() {
    return r'accountTaskResolverProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<TaskResolver> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TaskResolver create(Ref ref) {
    final argument = this.argument as String;
    return accountTaskResolver(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaskResolver value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaskResolver>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountTaskResolverProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountTaskResolverHash() =>
    r'402d8b3ad5856a2d700d9cc19d7861e94c6753aa';

final class AccountTaskResolverFamily extends $Family
    with $FunctionalFamilyOverride<TaskResolver, String> {
  AccountTaskResolverFamily._()
    : super(
        retry: null,
        name: r'accountTaskResolverProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountTaskResolverProvider call(String accountId) =>
      AccountTaskResolverProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountTaskResolverProvider';
}

/// The active account's; null while nobody is signed in.

@ProviderFor(taskResolver)
final taskResolverProvider = TaskResolverProvider._();

/// The active account's; null while nobody is signed in.

final class TaskResolverProvider
    extends $FunctionalProvider<TaskResolver?, TaskResolver?, TaskResolver?>
    with $Provider<TaskResolver?> {
  /// The active account's; null while nobody is signed in.
  TaskResolverProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taskResolverProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taskResolverHash();

  @$internal
  @override
  $ProviderElement<TaskResolver?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TaskResolver? create(Ref ref) {
    return taskResolver(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaskResolver? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaskResolver?>(value),
    );
  }
}

String _$taskResolverHash() => r'ff692a8062164ed290c9739d0a8686d4d934a7fa';
