// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'locale_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$localeOverrideHash() => r'0fddcfb0e4fa1e3f927a35352debac29865f1036';

/// Provides an optional locale override. When null, system locale is used.
///
/// Copied from [LocaleOverride].
@ProviderFor(LocaleOverride)
final localeOverrideProvider =
    AsyncNotifierProvider<LocaleOverride, Locale?>.internal(
      LocaleOverride.new,
      name: r'localeOverrideProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$localeOverrideHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$LocaleOverride = AsyncNotifier<Locale?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
