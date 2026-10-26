// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_check.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(sessionCheck)
final sessionCheckProvider = SessionCheckProvider._();

final class SessionCheckProvider
    extends $FunctionalProvider<SessionCheck, SessionCheck, SessionCheck>
    with $Provider<SessionCheck> {
  SessionCheckProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionCheckProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionCheckHash();

  @$internal
  @override
  $ProviderElement<SessionCheck> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SessionCheck create(Ref ref) {
    return sessionCheck(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionCheck value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionCheck>(value),
    );
  }
}

String _$sessionCheckHash() => r'1c77a9efa25053d820cb2378ec6fa8c139b6d308';
