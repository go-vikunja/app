// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_end_log.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(sessionEndLog)
final sessionEndLogProvider = SessionEndLogProvider._();

final class SessionEndLogProvider
    extends $FunctionalProvider<SessionEndLog, SessionEndLog, SessionEndLog>
    with $Provider<SessionEndLog> {
  SessionEndLogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionEndLogProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionEndLogHash();

  @$internal
  @override
  $ProviderElement<SessionEndLog> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SessionEndLog create(Ref ref) {
    return sessionEndLog(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionEndLog value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionEndLog>(value),
    );
  }
}

String _$sessionEndLogHash() => r'5f0dd39aebd647973472e09daeabd8d6ea8a0c65';
