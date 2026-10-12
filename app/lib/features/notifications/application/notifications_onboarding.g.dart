// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notifications_onboarding.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the permission setup has been shown on this device. The router
/// sends a signed-in, synced account to it until [markDone].

@ProviderFor(NotificationsOnboarding)
final notificationsOnboardingProvider = NotificationsOnboardingProvider._();

/// Whether the permission setup has been shown on this device. The router
/// sends a signed-in, synced account to it until [markDone].
final class NotificationsOnboardingProvider
    extends $AsyncNotifierProvider<NotificationsOnboarding, bool> {
  /// Whether the permission setup has been shown on this device. The router
  /// sends a signed-in, synced account to it until [markDone].
  NotificationsOnboardingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationsOnboardingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationsOnboardingHash();

  @$internal
  @override
  NotificationsOnboarding create() => NotificationsOnboarding();
}

String _$notificationsOnboardingHash() =>
    r'905ee2ef38d26dd90d111b8fd6fc89303bb68438';

/// Whether the permission setup has been shown on this device. The router
/// sends a signed-in, synced account to it until [markDone].

abstract class _$NotificationsOnboarding extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
