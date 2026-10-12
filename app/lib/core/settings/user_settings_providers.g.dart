// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_settings_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The active account's settings as the last sync stored them; the
/// server's defaults until then and while nobody is signed in.

@ProviderFor(userSettings)
final userSettingsProvider = UserSettingsProvider._();

/// The active account's settings as the last sync stored them; the
/// server's defaults until then and while nobody is signed in.

final class UserSettingsProvider
    extends
        $FunctionalProvider<
          AsyncValue<UserSettings>,
          UserSettings,
          Stream<UserSettings>
        >
    with $FutureModifier<UserSettings>, $StreamProvider<UserSettings> {
  /// The active account's settings as the last sync stored them; the
  /// server's defaults until then and while nobody is signed in.
  UserSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userSettingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userSettingsHash();

  @$internal
  @override
  $StreamProviderElement<UserSettings> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<UserSettings> create(Ref ref) {
    return userSettings(ref);
  }
}

String _$userSettingsHash() => r'3734d9c836e3ddc8b7972ef1f1f37ebdc7e0ac1c';
