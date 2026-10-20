// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The task's queued uploads in the active account, failed ones included.

@ProviderFor(pendingUploads)
final pendingUploadsProvider = PendingUploadsFamily._();

/// The task's queued uploads in the active account, failed ones included.

final class PendingUploadsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PendingUpload>>,
          List<PendingUpload>,
          Stream<List<PendingUpload>>
        >
    with
        $FutureModifier<List<PendingUpload>>,
        $StreamProvider<List<PendingUpload>> {
  /// The task's queued uploads in the active account, failed ones included.
  PendingUploadsProvider._({
    required PendingUploadsFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'pendingUploadsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$pendingUploadsHash();

  @override
  String toString() {
    return r'pendingUploadsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<PendingUpload>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<PendingUpload>> create(Ref ref) {
    final argument = this.argument as int;
    return pendingUploads(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PendingUploadsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$pendingUploadsHash() => r'62f5a60ca65934aeee850dcf63682d25e0a14435';

/// The task's queued uploads in the active account, failed ones included.

final class PendingUploadsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<PendingUpload>>, int> {
  PendingUploadsFamily._()
    : super(
        retry: null,
        name: r'pendingUploadsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The task's queued uploads in the active account, failed ones included.

  PendingUploadsProvider call(int taskId) =>
      PendingUploadsProvider._(argument: taskId, from: this);

  @override
  String toString() => r'pendingUploadsProvider';
}
