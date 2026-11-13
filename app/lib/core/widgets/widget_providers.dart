import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/app/theme/theme_providers.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/links/widget_link_key.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/security/privacy_providers.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/core/widgets/no_widget_host.dart';
import 'package:vikunja_mobile/core/widgets/plugin_widget_host.dart';
import 'package:vikunja_mobile/core/widgets/widget_config.dart';
import 'package:vikunja_mobile/core/widgets/widget_host.dart';
import 'package:vikunja_mobile/core/widgets/widget_publisher.dart';
import 'package:vikunja_mobile/core/widgets/widget_refresher.dart';
import 'package:vikunja_mobile/core/widgets/widget_snapshot.dart';
import 'package:vikunja_mobile/core/widgets/widget_snapshot_builder.dart';
import 'package:vikunja_mobile/core/widgets/widget_taps.dart';
import 'package:vikunja_mobile/core/widgets/widget_texts.dart';
import 'package:vikunja_widgets/vikunja_widgets.dart';

part 'widget_providers.g.dart';

final _log = Logger('Widgets');

@Riverpod(keepAlive: true)
WidgetHost widgetHost(Ref ref) => switch (defaultTargetPlatform) {
  TargetPlatform.android ||
  TargetPlatform.iOS => PluginWidgetHost(VikunjaWidgets()),
  _ => const NoWidgetHost(),
};

/// Where the app notes the device's 24-hour switch for a headless isolate,
/// whose engine has no view to read it from.
const widgetAlwaysUse24HourFormatKey = 'widgets.always_use_24h';

/// The device's 24-hour switch: read and noted by the app, the noted value
/// in a headless isolate (false before the app ever noted one).
@Riverpod(keepAlive: true)
Future<bool> widgetAlwaysUse24HourFormat(Ref ref) async {
  final preferences = ref.watch(preferencesStoreProvider);
  if (ref.watch(runsHeadlessProvider)) {
    return await preferences.getString(widgetAlwaysUse24HourFormatKey) ==
        'true';
  }
  final value = PlatformDispatcher.instance.alwaysUse24HourFormat;
  await preferences.setString(widgetAlwaysUse24HourFormatKey, '$value');
  return value;
}

@Riverpod(keepAlive: true)
Future<WidgetTexts> widgetTexts(Ref ref) async {
  final l10n = ref.watch(deviceAppLocalizationsProvider);
  return await WidgetTexts.load(
    l10n,
    alwaysUse24HourFormat: await ref.watch(
      widgetAlwaysUse24HourFormatProvider.future,
    ),
  );
}

/// iOS cannot tell the app which lists its widgets show, so the smart
/// lists and the quick add button are always written there.
@Riverpod(keepAlive: true)
Set<WidgetKind> widgetAlwaysPublishedKinds(Ref ref) =>
    defaultTargetPlatform == TargetPlatform.iOS
    ? {
        const TodayKind(),
        const UpcomingKind(3),
        const UpcomingKind(7),
        const UpcomingKind(14),
        const OverdueKind(),
        const FavoritesKind(),
        const QuickAddKind(),
      }
    : {};

@Riverpod(keepAlive: true)
WidgetPublishers widgetPublishers(Ref ref) => WidgetPublishers(
  host: ref.watch(widgetHostProvider),
  removedSnapshot: (key, accountId) => removedAccountSnapshot(
    key,
    accountId: accountId,
    l10n: ref.read(deviceAppLocalizationsProvider),
    now: ref.read(clockProvider)(),
  ),
);

/// One account's publisher; null once the account is gone. In the app it
/// publishes when built, when the app comes back to the front, when the
/// account's registry entry changes, when the "Show task titles in
/// widgets" switch changes, when the app's language changes and when its
/// snapshots go stale; a headless container publishes on request
/// ([widgetRefresherProvider]).
@Riverpod(keepAlive: true)
WidgetPublisher? widgetPublisher(Ref ref, String accountId) {
  final registered = ref.watch(
    accountsProvider.select(
      (accounts) => accounts.value?.find(accountId) != null,
    ),
  );
  if (!registered) return null;
  final headless = ref.watch(runsHeadlessProvider);
  final db = ref.watch(appDatabaseProvider(accountId));
  final now = ref.watch(clockProvider);
  final publisher = WidgetPublisher(
    accountId: accountId,
    db: db,
    host: ref.watch(widgetHostProvider),
    account: () => _widgetAccount(ref.read(accountsProvider).value, accountId),
    build: (account, kinds, {required withCatalog}) async {
      final texts = await ref.read(widgetTextsProvider.future);
      final privacy = await ref.read(privacySettingsProvider.future);
      final linkKey = await readWidgetLinkKey(
        ref.read(preferencesStoreProvider),
      );
      return await WidgetSnapshotBuilder(
        db: db,
        texts: texts,
        showTaskTitles: privacy.widgetTitles,
        linkKey: linkKey,
        now: now,
      ).build(account, kinds, withCatalog: withCatalog);
    },
    alwaysKinds: ref.watch(widgetAlwaysPublishedKindsProvider),
    refreshesAtValidity: !headless,
    now: now,
  );
  ref.watch(widgetPublishersProvider).register(publisher);
  ref
    ..listen(
      accountsProvider.select(
        (accounts) => _widgetAccount(accounts.value, accountId),
      ),
      (_, _) => publisher.publishSoon(),
    )
    ..listen(
      privacySettingsProvider.select((async) => async.value?.widgetTitles),
      (previous, next) {
        if (previous != null && next != null) publisher.publishQuietly();
      },
    );
  if (!headless) {
    ref.listen(
      deviceAppLocalizationsProvider,
      (_, _) => publisher.publishQuietly(),
    );
  }
  final lifecycle = headless
      ? null
      : AppLifecycleListener(
          onResume: () {
            // The device's 24-hour switch may have changed meanwhile.
            ref.invalidate(widgetAlwaysUse24HourFormatProvider);
            publisher.publishQuietly();
          },
        );
  ref.onDispose(() {
    lifecycle?.dispose();
    unawaited(publisher.dispose());
  });
  if (!headless) publisher.publishQuietly();
  return publisher;
}

WidgetAccount? _widgetAccount(AccountRegistryState? state, String accountId) =>
    switch (state?.find(accountId)) {
      final entry? => WidgetAccount.of(
        entry,
        showsAccount: state!.accounts.length > 1,
      ),
      null => null,
    };

/// One publisher per signed-in account while the shell listens, like
/// `accountNotificationSchedulersProvider`: the ids of the accounts that
/// have one.
@Riverpod(keepAlive: true)
Set<String> accountWidgetPublishers(Ref ref) {
  final joinedIds = ref.watch(
    accountsProvider.select(
      (accounts) => accounts.value?.accounts.map((e) => e.id).join('\n'),
    ),
  );
  if (joinedIds == null || joinedIds.isEmpty) return const {};
  return {
    for (final accountId in joinedIds.split('\n'))
      if (ref.watch(widgetPublisherProvider(accountId)) != null) accountId,
  };
}

@Riverpod(keepAlive: true)
WidgetRefresher widgetRefresher(Ref ref) => _ProviderWidgetRefresher(ref);

final class _ProviderWidgetRefresher implements WidgetRefresher {
  new(this._ref);

  final Ref _ref;

  @override
  Future<void> refresh(String accountId) async {
    try {
      await _ref.read(widgetPublisherProvider(accountId))?.publishNow();
    } on Object catch (error) {
      _log.warning(
        'Could not publish the widgets of account $accountId: '
        '${error.runtimeType}',
      );
    }
  }

  @override
  Future<void> refreshAll() async {
    final accounts = await _ref.read(accountsProvider.future);
    for (final entry in accounts.accounts) {
      await refresh(entry.id);
    }
  }

  @override
  Future<void> publish(WidgetConfig config) async {
    try {
      await _ref
          .read(widgetPublisherProvider(config.accountId))
          ?.publishNow(also: {config.kind});
      await _ref.read(widgetHostProvider).update({config.key});
    } on Object catch (error) {
      _log.warning(
        'Could not publish the widgets of account ${config.accountId}: '
        '${error.runtimeType}',
      );
    }
  }

  @override
  Future<WidgetSnapshot?> preview(WidgetConfig config) async => await _ref
      .read(widgetPublisherProvider(config.accountId))
      ?.preview(config.kind);
}

/// In the app: the widgets' Done taps (the iOS outbox, an Android queue
/// its worker could not drain) imported once the accounts are loaded and
/// whenever the app comes back to the front, one import at a time. The
/// shell keeps it listened.
@Riverpod(keepAlive: true)
WidgetTapImporter widgetTapImporter(Ref ref) {
  final importer = WidgetTapImporter(() => importWidgetTaps(ref.container));
  final lifecycle = AppLifecycleListener(onResume: importer.importQuietly);
  ref.onDispose(lifecycle.dispose);
  importer.importQuietly();
  return importer;
}

final class WidgetTapImporter {
  new(this._import);

  final Future<void> Function() _import;
  Future<void>? _running;
  var _requested = false;

  /// A call during an import makes it look once more.
  void importQuietly() {
    _requested = true;
    _running ??= _loop().whenComplete(() => _running = null);
  }

  Future<void> _loop() async {
    while (_requested) {
      _requested = false;
      await _import();
    }
  }
}

/// In the app: what an unconfigured Android list widget shows follows the
/// active account (its Today list, published at once), and every widget
/// follows the "Use system colours" switch. The native widgets put the
/// widget-link key into the links they build themselves. The shell keeps
/// it listened.
@Riverpod(keepAlive: true)
Future<void> widgetHostSettings(Ref ref) async {
  final activeAccountId = ref.watch(activeAccountIdProvider);
  final dynamicColor = await ref.watch(useSystemColorsProvider.future);
  final host = ref.watch(widgetHostProvider);
  final linkKey = await readWidgetLinkKey(ref.read(preferencesStoreProvider));
  try {
    await host.writeHost(
      activeAccountId: activeAccountId,
      dynamicColor: dynamicColor,
      linkKey: linkKey,
    );
    if (!ref.mounted) return;
    if (activeAccountId != null) {
      await ref.read(widgetRefresherProvider).refresh(activeAccountId);
    }
    await host.updateAll();
  } on Object catch (error) {
    _log.warning('Could not write the widget settings: ${error.runtimeType}');
  }
}
