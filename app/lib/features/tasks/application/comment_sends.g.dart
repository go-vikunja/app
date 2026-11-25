// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comment_sends.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(commentSends)
final commentSendsProvider = CommentSendsProvider._();

final class CommentSendsProvider
    extends $FunctionalProvider<CommentSends, CommentSends, CommentSends>
    with $Provider<CommentSends> {
  CommentSendsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'commentSendsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$commentSendsHash();

  @$internal
  @override
  $ProviderElement<CommentSends> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CommentSends create(Ref ref) {
    return commentSends(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CommentSends value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CommentSends>(value),
    );
  }
}

String _$commentSendsHash() => r'63654c779a8a5c79bdb3d811d05ab759e8009353';
