import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/router/pushed_pages.dart';
import 'package:vikunja_mobile/core/auth/account_title.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/platform/app_round_trips.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/security/app_excursions.dart';
import 'package:vikunja_mobile/core/widgets/widget_config.dart';
import 'package:vikunja_mobile/core/widgets/widget_providers.dart';
import 'package:vikunja_mobile/features/common/presentation/announce.dart';
import 'package:vikunja_mobile/features/common/presentation/list_note.dart';
import 'package:vikunja_mobile/features/common/presentation/screen_title.dart';
import 'package:vikunja_mobile/features/common/presentation/section_card.dart';
import 'package:vikunja_mobile/features/common/presentation/section_semantics.dart';
import 'package:vikunja_mobile/features/widgets/presentation/widget_kind_texts.dart';

final _log = Logger('WidgetsPage');

/// How to put the home-screen widgets on the home screen, per platform. On
/// Android the common kinds can be added from here for the active account
/// where the launcher can pin them (it asks first), and the placed widgets
/// open their setup, which is the only way to set one up where the launcher
/// offers no widget settings (Android 11 and older, some launchers).
class WidgetsPage extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<WidgetsPage> createState() => _WidgetsPageState();
}

class _WidgetsPageState extends ConsumerState<WidgetsPage> {
  static const _addable = <WidgetKind>[
    TodayKind(),
    UpcomingKind(7),
    OverdueKind(),
    FavoritesKind(),
    QuickAddKind(),
  ];

  late final AppLifecycleListener _lifecycle;
  late final Future<bool> _canPin;
  Future<List<_PlacedWidget>>? _placed;

  /// A snackbar would not fit above a tall tab bar in large text.
  var _pinUnsupported = false;

  @override
  void initState() {
    super.initState();
    // A widget added or removed on the home screen shows when the app
    // comes back.
    _lifecycle = AppLifecycleListener(onResume: _loadPlaced);
    _canPin = _readCanPin();
    _placed = _readPlaced();
  }

  Future<bool> _readCanPin() async {
    try {
      return await ref.read(widgetHostProvider).canRequestPin();
    } on Object catch (error) {
      _log.fine(
        'Could not ask whether widgets can be added: ${error.runtimeType}',
      );
      return false;
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _loadPlaced() {
    if (!mounted) return;
    final placed = _readPlaced();
    setState(() {
      _placed = placed;
    });
  }

  Future<List<_PlacedWidget>> _readPlaced() async {
    final Map<int, WidgetConfig?> configs;
    try {
      configs = await ref.read(widgetHostProvider).configs();
    } on Object catch (error) {
      _log.warning('Could not read the placed widgets: ${error.runtimeType}');
      return const [];
    }
    final refresher = ref.read(widgetRefresherProvider);
    final ids = configs.keys.toList()..sort();
    return [
      for (final id in ids)
        _PlacedWidget(
          appWidgetId: id,
          config: configs[id],
          title: switch (configs[id]) {
            final config? => (await refresher.preview(config))?.title,
            null => null,
          },
        ),
    ];
  }

  Future<void> _add(WidgetKind kind) async {
    final accountId = ref.read(activeAccountIdProvider);
    if (accountId == null) return;
    final config = WidgetConfig(accountId: accountId, kind: kind);
    var requested = false;
    try {
      // The launcher draws the placed widget at once, from this snapshot.
      await ref.read(widgetRefresherProvider).publish(config);
      // The launcher's dialog does not lock the app.
      requested = await ref
          .read(appExcursionsProvider)
          .launchAway(
            () => ref.read(widgetHostProvider).requestPin(config),
            opened: (requested) => requested,
          );
    } on Object catch (error) {
      _log.warning('Could not ask to place a widget: ${error.runtimeType}');
    }
    if (requested || !mounted) return;
    setState(() => _pinUnsupported = true);
    announce(context, context.l10n.widgetsPinUnsupported);
  }

  Future<void> _configure(int appWidgetId) async {
    await context.pushPage<void>(AppRoutes.widgetConfigure(appWidgetId));
    _loadPlaced();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final android = theme.platform == TargetPlatform.android;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Scaffold(
      appBar: AppBar(title: ScreenTitle(l10n.widgetsTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(l10n.widgetsIntro, style: theme.textTheme.bodyLarge),
            ),
            SectionCard(
              title: l10n.widgetsHowToHeading,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    android ? l10n.widgetsHowToAndroid : l10n.widgetsHowToIos,
                  ),
                ),
              ],
            ),
            if (android) ...[
              FutureBuilder<bool>(
                future: _canPin,
                builder: (context, canPin) => canPin.data ?? false
                    ? SectionSemantics(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SectionCard(
                              title: l10n.widgetsAddHeading,
                              children: [
                                for (final kind in _addable)
                                  _AddTile(
                                    kind: kind,
                                    onAdd: () => unawaited(_add(kind)),
                                  ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                              child: Text(l10n.widgetsAddHint, style: muted),
                            ),
                            if (_pinUnsupported)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  0,
                                ),
                                child: ListNote(
                                  icon: Icons.info_outline,
                                  text: l10n.widgetsPinUnsupported,
                                ),
                              ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              _PlacedSection(placed: _placed, onConfigure: _configure),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: ListNote(
                icon: Icons.visibility_outlined,
                text: l10n.widgetsPrivacyNote,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const new({required this.kind, required this.onAdd});

  final WidgetKind kind;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hint = switch (kind) {
      TodayKind() => l10n.widgetKindTodayHint,
      UpcomingKind(:final days) =>
        '${l10n.widgetKindUpcomingHint} · ${l10n.widgetUpcomingDays(days)}',
      OverdueKind() => l10n.widgetKindOverdueHint,
      FavoritesKind() => l10n.widgetKindFavoritesHint,
      QuickAddKind() => l10n.widgetKindQuickAddHint,
      _ => null,
    };
    return Semantics(
      onTapHint: l10n.widgetsAdd,
      child: ListTile(
        leading: Icon(widgetKindIcon(kind)),
        title: Text(widgetKindTitle(l10n, kind)),
        subtitle: hint == null ? null : Text(hint),
        trailing: const Icon(Icons.add_circle_outline),
        onTap: onAdd,
      ),
    );
  }
}

final class _PlacedWidget {
  const new({required this.appWidgetId, this.config, this.title});

  final int appWidgetId;

  /// Null for a list widget not set up, which shows the active account's
  /// Today.
  final WidgetConfig? config;

  /// What its header says; null for an account that is gone.
  final String? title;
}

class _PlacedSection extends ConsumerWidget {
  const new({required this.placed, required this.onConfigure});

  final Future<List<_PlacedWidget>>? placed;
  final void Function(int appWidgetId) onConfigure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final registry = ref.watch(accountsProvider).value;
    final several = (registry?.accounts.length ?? 0) > 1;
    return FutureBuilder<List<_PlacedWidget>>(
      future: placed,
      builder: (context, snapshot) {
        final widgets = snapshot.data ?? const <_PlacedWidget>[];
        if (widgets.isEmpty) return const SizedBox.shrink();
        return SectionCard(
          title: l10n.widgetsPlacedHeading,
          children: [
            for (final widget in widgets)
              switch (widget.config) {
                final config? => _placedTile(
                  context,
                  widget.appWidgetId,
                  config,
                  widget.title,
                  registry?.find(config.accountId)?.account,
                  several: several,
                ),
                null => _notSetUpTile(context, widget.appWidgetId),
              },
          ],
        );
      },
    );
  }

  Widget _placedTile(
    BuildContext context,
    int appWidgetId,
    WidgetConfig config,
    String? previewTitle,
    Account? account, {
    required bool several,
  }) {
    final l10n = context.l10n;
    final kindTitle = widgetKindTitle(l10n, config.kind);
    final title = previewTitle ?? kindTitle;
    final String? subtitle;
    if (account == null) {
      subtitle = l10n.widgetsPlacedAccountRemoved;
    } else if (several) {
      subtitle = '$kindTitle · ${accountTitle(account)}';
    } else {
      subtitle = title == kindTitle ? null : kindTitle;
    }
    return ListTile(
      key: ValueKey(appWidgetId),
      leading: Icon(widgetKindIcon(config.kind)),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => onConfigure(appWidgetId),
    );
  }

  Widget _notSetUpTile(BuildContext context, int appWidgetId) {
    final l10n = context.l10n;
    const kind = TodayKind();
    return ListTile(
      key: ValueKey(appWidgetId),
      leading: Icon(widgetKindIcon(kind)),
      title: Text(widgetKindTitle(l10n, kind)),
      subtitle: Text(l10n.widgetsPlacedNotSetUp),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => onConfigure(appWidgetId),
    );
  }
}
