// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comment_drafts.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(commentDrafts)
final commentDraftsProvider = CommentDraftsProvider._();

final class CommentDraftsProvider
    extends $FunctionalProvider<CommentDrafts, CommentDrafts, CommentDrafts>
    with $Provider<CommentDrafts> {
  CommentDraftsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'commentDraftsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$commentDraftsHash();

  @$internal
  @override
  $ProviderElement<CommentDrafts> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CommentDrafts create(Ref ref) {
    return commentDrafts(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CommentDrafts value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CommentDrafts>(value),
    );
  }
}

String _$commentDraftsHash() => r'ff720c647cf74eeb394404e182263ef9897f5c03';
