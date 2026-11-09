// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_opener.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(accountServerTaskRead)
final accountServerTaskReadProvider = AccountServerTaskReadFamily._();

final class AccountServerTaskReadProvider
    extends $FunctionalProvider<ServerTaskRead, ServerTaskRead, ServerTaskRead>
    with $Provider<ServerTaskRead> {
  AccountServerTaskReadProvider._({
    required AccountServerTaskReadFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountServerTaskReadProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountServerTaskReadHash();

  @override
  String toString() {
    return r'accountServerTaskReadProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<ServerTaskRead> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ServerTaskRead create(Ref ref) {
    final argument = this.argument as String;
    return accountServerTaskRead(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ServerTaskRead value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ServerTaskRead>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountServerTaskReadProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountServerTaskReadHash() =>
    r'bf083c97214d3d3ad610353dba5f74e9ad05fb7e';

final class AccountServerTaskReadFamily extends $Family
    with $FunctionalFamilyOverride<ServerTaskRead, String> {
  AccountServerTaskReadFamily._()
    : super(
        retry: null,
        name: r'accountServerTaskReadProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountServerTaskReadProvider call(String accountId) =>
      AccountServerTaskReadProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountServerTaskReadProvider';
}

@ProviderFor(taskOpener)
final taskOpenerProvider = TaskOpenerProvider._();

final class TaskOpenerProvider
    extends $FunctionalProvider<TaskOpener, TaskOpener, TaskOpener>
    with $Provider<TaskOpener> {
  TaskOpenerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taskOpenerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taskOpenerHash();

  @$internal
  @override
  $ProviderElement<TaskOpener> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TaskOpener create(Ref ref) {
    return taskOpener(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaskOpener value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaskOpener>(value),
    );
  }
}

String _$taskOpenerHash() => r'e9e0737292188f24cfc8983c5b010a33a38f03bc';
