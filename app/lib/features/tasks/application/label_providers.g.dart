// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'label_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every label the account can attach, by title; stays loading without an
/// account.

@ProviderFor(allLabels)
final allLabelsProvider = AllLabelsProvider._();

/// Every label the account can attach, by title; stays loading without an
/// account.

final class AllLabelsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Label>>,
          List<Label>,
          Stream<List<Label>>
        >
    with $FutureModifier<List<Label>>, $StreamProvider<List<Label>> {
  /// Every label the account can attach, by title; stays loading without an
  /// account.
  AllLabelsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allLabelsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allLabelsHash();

  @$internal
  @override
  $StreamProviderElement<List<Label>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Label>> create(Ref ref) {
    return allLabels(ref);
  }
}

String _$allLabelsHash() => r'3d7d04c4fc4b501f40c29107f3fd32d3a8959f9c';

/// One label, followed to the server id once a label created here is
/// answered; null while it is not here.

@ProviderFor(labelById)
final labelByIdProvider = LabelByIdFamily._();

/// One label, followed to the server id once a label created here is
/// answered; null while it is not here.

final class LabelByIdProvider
    extends $FunctionalProvider<AsyncValue<Label?>, Label?, Stream<Label?>>
    with $FutureModifier<Label?>, $StreamProvider<Label?> {
  /// One label, followed to the server id once a label created here is
  /// answered; null while it is not here.
  LabelByIdProvider._({
    required LabelByIdFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'labelByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$labelByIdHash();

  @override
  String toString() {
    return r'labelByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Label?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Label?> create(Ref ref) {
    final argument = this.argument as int;
    return labelById(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LabelByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$labelByIdHash() => r'63b7150ae5956e9690ff932b3e6a9e6ea235101b';

/// One label, followed to the server id once a label created here is
/// answered; null while it is not here.

final class LabelByIdFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Label?>, int> {
  LabelByIdFamily._()
    : super(
        retry: null,
        name: r'labelByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One label, followed to the server id once a label created here is
  /// answered; null while it is not here.

  LabelByIdProvider call(int id) =>
      LabelByIdProvider._(argument: id, from: this);

  @override
  String toString() => r'labelByIdProvider';
}

/// The labels with a change the server does not have yet.

@ProviderFor(pendingLabelIds)
final pendingLabelIdsProvider = PendingLabelIdsProvider._();

/// The labels with a change the server does not have yet.

final class PendingLabelIdsProvider
    extends
        $FunctionalProvider<AsyncValue<Set<int>>, Set<int>, Stream<Set<int>>>
    with $FutureModifier<Set<int>>, $StreamProvider<Set<int>> {
  /// The labels with a change the server does not have yet.
  PendingLabelIdsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingLabelIdsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingLabelIdsHash();

  @$internal
  @override
  $StreamProviderElement<Set<int>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Set<int>> create(Ref ref) {
    return pendingLabelIds(ref);
  }
}

String _$pendingLabelIdsHash() => r'1dc578fd758dbc93495b252453718cf192ae0b6f';

/// Every temporary label id with the server id its label got.

@ProviderFor(labelRemaps)
final labelRemapsProvider = LabelRemapsProvider._();

/// Every temporary label id with the server id its label got.

final class LabelRemapsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<int, int>>,
          Map<int, int>,
          Stream<Map<int, int>>
        >
    with $FutureModifier<Map<int, int>>, $StreamProvider<Map<int, int>> {
  /// Every temporary label id with the server id its label got.
  LabelRemapsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'labelRemapsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$labelRemapsHash();

  @$internal
  @override
  $StreamProviderElement<Map<int, int>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<int, int>> create(Ref ref) {
    return labelRemaps(ref);
  }
}

String _$labelRemapsHash() => r'3bf2e36d734cfac748288fc5a1da57259ee521e1';
