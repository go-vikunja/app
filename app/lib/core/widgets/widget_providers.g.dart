// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'widget_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(widgetHost)
final widgetHostProvider = WidgetHostProvider._();

final class WidgetHostProvider
    extends $FunctionalProvider<WidgetHost, WidgetHost, WidgetHost>
    with $Provider<WidgetHost> {
  WidgetHostProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'widgetHostProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$widgetHostHash();

  @$internal
  @override
  $ProviderElement<WidgetHost> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WidgetHost create(Ref ref) {
    return widgetHost(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WidgetHost value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WidgetHost>(value),
    );
  }
}

String _$widgetHostHash() => r'b9bfd13bcee5e0812a0e25fbe0d5eebdf00baa86';

/// The device's 24-hour switch: read and noted by the app, the noted value
/// in a headless isolate (false before the app ever noted one).

@ProviderFor(widgetAlwaysUse24HourFormat)
final widgetAlwaysUse24HourFormatProvider =
    WidgetAlwaysUse24HourFormatProvider._();

/// The device's 24-hour switch: read and noted by the app, the noted value
/// in a headless isolate (false before the app ever noted one).

final class WidgetAlwaysUse24HourFormatProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// The device's 24-hour switch: read and noted by the app, the noted value
  /// in a headless isolate (false before the app ever noted one).
  WidgetAlwaysUse24HourFormatProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'widgetAlwaysUse24HourFormatProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$widgetAlwaysUse24HourFormatHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return widgetAlwaysUse24HourFormat(ref);
  }
}

String _$widgetAlwaysUse24HourFormatHash() =>
    r'ab67222fafa895f303e779c7c0de71411f7aabb7';

@ProviderFor(widgetTexts)
final widgetTextsProvider = WidgetTextsProvider._();

final class WidgetTextsProvider
    extends
        $FunctionalProvider<
          AsyncValue<WidgetTexts>,
          WidgetTexts,
          FutureOr<WidgetTexts>
        >
    with $FutureModifier<WidgetTexts>, $FutureProvider<WidgetTexts> {
  WidgetTextsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'widgetTextsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$widgetTextsHash();

  @$internal
  @override
  $FutureProviderElement<WidgetTexts> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<WidgetTexts> create(Ref ref) {
    return widgetTexts(ref);
  }
}

String _$widgetTextsHash() => r'e04de95caf2b4fc229db20235c8fe2af8efc79d0';

/// iOS cannot tell the app which lists its widgets show, so the smart
/// lists and the quick add button are always written there.

@ProviderFor(widgetAlwaysPublishedKinds)
final widgetAlwaysPublishedKindsProvider =
    WidgetAlwaysPublishedKindsProvider._();

/// iOS cannot tell the app which lists its widgets show, so the smart
/// lists and the quick add button are always written there.

final class WidgetAlwaysPublishedKindsProvider
    extends
        $FunctionalProvider<Set<WidgetKind>, Set<WidgetKind>, Set<WidgetKind>>
    with $Provider<Set<WidgetKind>> {
  /// iOS cannot tell the app which lists its widgets show, so the smart
  /// lists and the quick add button are always written there.
  WidgetAlwaysPublishedKindsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'widgetAlwaysPublishedKindsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$widgetAlwaysPublishedKindsHash();

  @$internal
  @override
  $ProviderElement<Set<WidgetKind>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Set<WidgetKind> create(Ref ref) {
    return widgetAlwaysPublishedKinds(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<WidgetKind> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<WidgetKind>>(value),
    );
  }
}

String _$widgetAlwaysPublishedKindsHash() =>
    r'3bb0255e8802789c3154ec2de397e0f323ec724e';

@ProviderFor(widgetPublishers)
final widgetPublishersProvider = WidgetPublishersProvider._();

final class WidgetPublishersProvider
    extends
        $FunctionalProvider<
          WidgetPublishers,
          WidgetPublishers,
          WidgetPublishers
        >
    with $Provider<WidgetPublishers> {
  WidgetPublishersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'widgetPublishersProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$widgetPublishersHash();

  @$internal
  @override
  $ProviderElement<WidgetPublishers> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WidgetPublishers create(Ref ref) {
    return widgetPublishers(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WidgetPublishers value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WidgetPublishers>(value),
    );
  }
}

String _$widgetPublishersHash() => r'80bc294a14f93de6b77d358f4828aa70a882403e';

/// One account's publisher; null once the account is gone. In the app it
/// publishes when built, when the app comes back to the front, when the
/// account's registry entry changes, when the "Show task titles in
/// widgets" switch changes, when the app's language changes and when its
/// snapshots go stale; a headless container publishes on request
/// ([widgetRefresherProvider]).

@ProviderFor(widgetPublisher)
final widgetPublisherProvider = WidgetPublisherFamily._();

/// One account's publisher; null once the account is gone. In the app it
/// publishes when built, when the app comes back to the front, when the
/// account's registry entry changes, when the "Show task titles in
/// widgets" switch changes, when the app's language changes and when its
/// snapshots go stale; a headless container publishes on request
/// ([widgetRefresherProvider]).

final class WidgetPublisherProvider
    extends
        $FunctionalProvider<
          WidgetPublisher?,
          WidgetPublisher?,
          WidgetPublisher?
        >
    with $Provider<WidgetPublisher?> {
  /// One account's publisher; null once the account is gone. In the app it
  /// publishes when built, when the app comes back to the front, when the
  /// account's registry entry changes, when the "Show task titles in
  /// widgets" switch changes, when the app's language changes and when its
  /// snapshots go stale; a headless container publishes on request
  /// ([widgetRefresherProvider]).
  WidgetPublisherProvider._({
    required WidgetPublisherFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'widgetPublisherProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$widgetPublisherHash();

  @override
  String toString() {
    return r'widgetPublisherProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<WidgetPublisher?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WidgetPublisher? create(Ref ref) {
    final argument = this.argument as String;
    return widgetPublisher(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WidgetPublisher? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WidgetPublisher?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WidgetPublisherProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$widgetPublisherHash() => r'7b910aeaa0d1588852358c7806d714e82f75f433';

/// One account's publisher; null once the account is gone. In the app it
/// publishes when built, when the app comes back to the front, when the
/// account's registry entry changes, when the "Show task titles in
/// widgets" switch changes, when the app's language changes and when its
/// snapshots go stale; a headless container publishes on request
/// ([widgetRefresherProvider]).

final class WidgetPublisherFamily extends $Family
    with $FunctionalFamilyOverride<WidgetPublisher?, String> {
  WidgetPublisherFamily._()
    : super(
        retry: null,
        name: r'widgetPublisherProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// One account's publisher; null once the account is gone. In the app it
  /// publishes when built, when the app comes back to the front, when the
  /// account's registry entry changes, when the "Show task titles in
  /// widgets" switch changes, when the app's language changes and when its
  /// snapshots go stale; a headless container publishes on request
  /// ([widgetRefresherProvider]).

  WidgetPublisherProvider call(String accountId) =>
      WidgetPublisherProvider._(argument: accountId, from: this);

  @override
  String toString() => r'widgetPublisherProvider';
}

/// One publisher per signed-in account while the shell listens, like
/// `accountNotificationSchedulersProvider`: the ids of the accounts that
/// have one.

@ProviderFor(accountWidgetPublishers)
final accountWidgetPublishersProvider = AccountWidgetPublishersProvider._();

/// One publisher per signed-in account while the shell listens, like
/// `accountNotificationSchedulersProvider`: the ids of the accounts that
/// have one.

final class AccountWidgetPublishersProvider
    extends $FunctionalProvider<Set<String>, Set<String>, Set<String>>
    with $Provider<Set<String>> {
  /// One publisher per signed-in account while the shell listens, like
  /// `accountNotificationSchedulersProvider`: the ids of the accounts that
  /// have one.
  AccountWidgetPublishersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountWidgetPublishersProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountWidgetPublishersHash();

  @$internal
  @override
  $ProviderElement<Set<String>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Set<String> create(Ref ref) {
    return accountWidgetPublishers(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$accountWidgetPublishersHash() =>
    r'bad0a21bacc6ac4260c54301845c57b5253315b7';

@ProviderFor(widgetRefresher)
final widgetRefresherProvider = WidgetRefresherProvider._();

final class WidgetRefresherProvider
    extends
        $FunctionalProvider<WidgetRefresher, WidgetRefresher, WidgetRefresher>
    with $Provider<WidgetRefresher> {
  WidgetRefresherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'widgetRefresherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$widgetRefresherHash();

  @$internal
  @override
  $ProviderElement<WidgetRefresher> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WidgetRefresher create(Ref ref) {
    return widgetRefresher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WidgetRefresher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WidgetRefresher>(value),
    );
  }
}

String _$widgetRefresherHash() => r'756fc717560be8399a6c447e87be8d1914d926be';

/// In the app: the widgets' Done taps (the iOS outbox, an Android queue
/// its worker could not drain) imported once the accounts are loaded and
/// whenever the app comes back to the front, one import at a time. The
/// shell keeps it listened.

@ProviderFor(widgetTapImporter)
final widgetTapImporterProvider = WidgetTapImporterProvider._();

/// In the app: the widgets' Done taps (the iOS outbox, an Android queue
/// its worker could not drain) imported once the accounts are loaded and
/// whenever the app comes back to the front, one import at a time. The
/// shell keeps it listened.

final class WidgetTapImporterProvider
    extends
        $FunctionalProvider<
          WidgetTapImporter,
          WidgetTapImporter,
          WidgetTapImporter
        >
    with $Provider<WidgetTapImporter> {
  /// In the app: the widgets' Done taps (the iOS outbox, an Android queue
  /// its worker could not drain) imported once the accounts are loaded and
  /// whenever the app comes back to the front, one import at a time. The
  /// shell keeps it listened.
  WidgetTapImporterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'widgetTapImporterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$widgetTapImporterHash();

  @$internal
  @override
  $ProviderElement<WidgetTapImporter> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WidgetTapImporter create(Ref ref) {
    return widgetTapImporter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WidgetTapImporter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WidgetTapImporter>(value),
    );
  }
}

String _$widgetTapImporterHash() => r'c09bd226c46e312b4f0f04602e9576137e67b1f5';

/// In the app: what an unconfigured Android list widget shows follows the
/// active account (its Today list, published at once), and every widget
/// follows the "Use system colours" switch. The native widgets put the
/// widget-link key into the links they build themselves. The shell keeps
/// it listened.

@ProviderFor(widgetHostSettings)
final widgetHostSettingsProvider = WidgetHostSettingsProvider._();

/// In the app: what an unconfigured Android list widget shows follows the
/// active account (its Today list, published at once), and every widget
/// follows the "Use system colours" switch. The native widgets put the
/// widget-link key into the links they build themselves. The shell keeps
/// it listened.

final class WidgetHostSettingsProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// In the app: what an unconfigured Android list widget shows follows the
  /// active account (its Today list, published at once), and every widget
  /// follows the "Use system colours" switch. The native widgets put the
  /// widget-link key into the links they build themselves. The shell keeps
  /// it listened.
  WidgetHostSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'widgetHostSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$widgetHostSettingsHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return widgetHostSettings(ref);
  }
}

String _$widgetHostSettingsHash() =>
    r'cc01370762c07432e3e9ecf8ffdb9f70d74aa962';
