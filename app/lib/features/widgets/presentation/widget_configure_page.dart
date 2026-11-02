import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/platform/app_backgrounding.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/core/text/title_order.dart';
import 'package:vikunja_mobile/core/widgets/widget_config.dart';
import 'package:vikunja_mobile/core/widgets/widget_providers.dart';
import 'package:vikunja_mobile/core/widgets/widget_snapshot.dart';
import 'package:vikunja_mobile/features/accounts/presentation/account_identity.dart';
import 'package:vikunja_mobile/features/common/presentation/app_bar_text_action.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/project_icon.dart';
import 'package:vikunja_mobile/features/common/presentation/screen_title.dart';
import 'package:vikunja_mobile/features/common/presentation/section_card.dart';
import 'package:vikunja_mobile/features/projects/application/project_tree.dart';
import 'package:vikunja_mobile/features/widgets/application/widget_choices.dart';
import 'package:vikunja_mobile/features/widgets/presentation/widget_kind_texts.dart';

final _log = Logger('WidgetConfigure');

/// The setup of one placed Android widget: its account, what it shows and
/// the list's project, label, saved filter or days, with a preview of what
/// it would show now. Save stores the setup and writes the widget's data.
/// Any app can send the link that opens it, so an id that is not one of
/// the app's placed widgets, or placed widgets that cannot be read, get a
/// refusal instead (iOS, which sets widgets up in their own settings,
/// always).
class WidgetConfigurePage extends ConsumerStatefulWidget {
  const new({required this.appWidgetId, this.fromWidget = false, super.key});

  final int appWidgetId;

  /// Opened from the home screen (the launcher's settings or the widget's
  /// "Set up"), where Save returns to.
  final bool fromWidget;

  @override
  ConsumerState<WidgetConfigurePage> createState() =>
      _WidgetConfigurePageState();
}

/// The kinds of a list widget, whatever their parameter.
enum _ListChoice {
  today,
  upcoming,
  overdue,
  favorites,
  project,
  label,
  savedFilter,
}

class _WidgetConfigurePageState extends ConsumerState<WidgetConfigurePage> {
  String? _accountId;
  WidgetKind? _kind;
  var _saving = false;
  var _refused = false;
  Future<WidgetSnapshot?>? _preview;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final Map<int, WidgetConfig?> configs;
    try {
      configs = await ref.read(widgetHostProvider).configs();
    } on Object catch (error) {
      _log.warning('Could not read the widget configs: ${error.runtimeType}');
      if (mounted) setState(() => _refused = true);
      return;
    }
    if (!mounted) return;
    if (!configs.containsKey(widget.appWidgetId)) {
      _log.info('Refused to set up a widget that is not placed');
      setState(() => _refused = true);
      return;
    }
    final registry = ref.read(accountsProvider).value;
    final saved = configs[widget.appWidgetId];
    final keep = saved != null && registry?.find(saved.accountId) != null;
    setState(() {
      _accountId = keep ? saved.accountId : registry?.activeAccountId;
      _kind = keep
          ? saved.kind
          : saved?.kind is QuickAddKind
          ? const QuickAddKind()
          : const TodayKind();
    });
    _updatePreview();
  }

  WidgetConfig? get _config => switch ((_accountId, _kind)) {
    (final accountId?, final kind?) => WidgetConfig(
      accountId: accountId,
      kind: kind,
    ),
    _ => null,
  };

  void _updatePreview() {
    final config = _config;
    if (config == null) return;
    final preview = ref.read(widgetRefresherProvider).preview(config);
    setState(() {
      _preview = preview;
    });
  }

  void _selectAccount(RegisteredAccount entry) {
    if (entry.id == _accountId) return;
    final kind = _kind;
    setState(() {
      _accountId = entry.id;
      // Ids belong to their account.
      if (kind is ProjectTasksKind ||
          kind is LabelTasksKind ||
          kind is SavedFilterKind) {
        _kind = const TodayKind();
      }
    });
    _updatePreview();
  }

  void _selectKind(WidgetKind kind) {
    if (kind == _kind) return;
    setState(() => _kind = kind);
    _updatePreview();
  }

  Future<void> _choose(_ListChoice choice) async {
    final accountId = _accountId;
    if (accountId == null) return;
    switch (choice) {
      case _ListChoice.today:
        _selectKind(const TodayKind());
      case _ListChoice.upcoming:
        if (_kind is! UpcomingKind) _selectKind(const UpcomingKind(7));
      case _ListChoice.overdue:
        _selectKind(const OverdueKind());
      case _ListChoice.favorites:
        _selectKind(const FavoritesKind());
      case _ListChoice.project:
        final id = await _pick(
          title: context.l10n.widgetKindProject,
          empty: context.l10n.widgetConfigureNoProjects,
          choices: _projectChoices(accountId),
          selectedId: switch (_kind) {
            ProjectTasksKind(:final projectId) => projectId,
            _ => null,
          },
        );
        if (id != null && mounted) _selectKind(ProjectTasksKind(id));
      case _ListChoice.label:
        final id = await _pick(
          title: context.l10n.widgetKindLabel,
          empty: context.l10n.widgetConfigureNoLabels,
          choices: _labelChoices(accountId),
          selectedId: switch (_kind) {
            LabelTasksKind(:final labelId) => labelId,
            _ => null,
          },
        );
        if (id != null && mounted) _selectKind(LabelTasksKind(id));
      case _ListChoice.savedFilter:
        final id = await _pick(
          title: context.l10n.widgetKindSavedFilter,
          empty: context.l10n.widgetConfigureNoSavedFilters,
          choices: _savedFilterChoices(accountId),
          selectedId: switch (_kind) {
            SavedFilterKind(:final filterId) => filterId,
            _ => null,
          },
        );
        if (id != null && mounted) _selectKind(SavedFilterKind(id));
    }
  }

  List<_Choice> _projectChoices(String accountId) {
    final l10n = context.l10n;
    final projects =
        ref.read(widgetProjectChoicesProvider(accountId)).value ?? const [];
    return [
      for (final row in flattenProjectTree(
        buildProjectTree(projects),
        collapsedIds: const {},
      ))
        _Choice(
          id: row.node.project.id,
          title: row.node.project.displayTitle(l10n),
          depth: row.depth,
          leading: ProjectIcon(hexColor: row.node.project.hexColor),
        ),
    ];
  }

  List<_Choice> _labelChoices(String accountId) {
    final labels = [...?ref.read(widgetLabelChoicesProvider(accountId)).value]
      ..sort((a, b) => compareTitles(a.title, b.title));
    return [
      for (final label in labels)
        _Choice(
          id: label.id,
          title: label.title,
          leading: switch (parseHexColor(label.hexColor)) {
            null => null,
            final color => Icon(Icons.circle, size: 12, color: color),
          },
        ),
    ];
  }

  List<_Choice> _savedFilterChoices(String accountId) => [
    for (final filter
        in ref.read(widgetSavedFilterChoicesProvider(accountId)).value ??
            const <SavedFilterRef>[])
      _Choice(
        id: filter.filterId,
        title: projectDisplayTitle(context.l10n, filter.title),
      ),
  ];

  Future<int?> _pick({
    required String title,
    required String empty,
    required List<_Choice> choices,
    required int? selectedId,
  }) => showModalBottomSheet<int>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scrollController) => _ChoiceList(
        title: title,
        empty: empty,
        choices: choices,
        selectedId: selectedId,
        scrollController: scrollController,
      ),
    ),
  );

  Future<void> _save() async {
    final config = _config;
    if (config == null || _saving) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref.read(widgetHostProvider).saveConfig(widget.appWidgetId, config);
      await ref.read(widgetRefresherProvider).publish(config);
    } on Object catch (error) {
      _log.warning('Could not save a widget: ${error.runtimeType}');
      if (!mounted) return;
      setState(() => _saving = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.widgetConfigureSaveFailed)));
      return;
    }
    if (!mounted) return;
    final background = widget.fromWidget
        ? ref.read(appBackgroundingProvider)
        : null;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.widgetConfigureSaved)));
    context.pop();
    if (background != null) {
      unawaited(
        background.moveToBack().catchError((Object error) {
          _log.fine(
            'Could not go back to the home screen: '
            '${error.runtimeType}',
          );
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_refused) {
      return Scaffold(
        appBar: AppBar(title: ScreenTitle(l10n.widgetConfigureTitle)),
        body: CenteredScrollView(
          maxWidth: ReadableWidth.form,
          child: EmptyState(
            icon: Icons.widgets_outlined,
            title: l10n.widgetConfigureUnknownTitle,
            body: l10n.widgetConfigureUnknownBody,
          ),
        ),
      );
    }
    final registry = ref.watch(accountsProvider).value;
    final accountId = _accountId;
    final kind = _kind;
    final entry = accountId == null ? null : registry?.find(accountId);
    return Scaffold(
      appBar: AppBar(
        title: ScreenTitle(l10n.widgetConfigureTitle),
        actions: [
          AppBarTextAction(
            onPressed: _config == null || _saving
                ? null
                : () => unawaited(_save()),
            child: Text(
              _saving ? l10n.widgetConfigureSaving : l10n.widgetConfigureSave,
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: _saving
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: SafeArea(
        top: false,
        child: kind == null || registry == null
            ? const Center(child: CircularProgressIndicator.adaptive())
            : ReadableWidth.builder(
                maxWidth: ReadableWidth.form,
                builder: (_, _, inset) => ListView(
                  padding: EdgeInsets.fromLTRB(inset, 0, inset, 24),
                  children: [
                    if (registry.accounts.length > 1)
                      SectionCard(
                        title: l10n.widgetConfigureAccountHeading,
                        children: [
                          for (final account in registry.accountsByRecency)
                            _AccountChoice(
                              entry: account,
                              selected: account.id == accountId,
                              onTap: _saving
                                  ? null
                                  : () => _selectAccount(account),
                            ),
                        ],
                      ),
                    if (kind is! QuickAddKind && entry != null)
                      _ListSection(
                        accountId: entry.id,
                        guest: entry.account.isLinkShare,
                        kind: kind,
                        enabled: !_saving,
                        onChoose: (choice) => unawaited(_choose(choice)),
                        onDays: (days) => _selectKind(UpcomingKind(days)),
                      ),
                    SectionCard(
                      title: l10n.widgetConfigurePreviewHeading,
                      children: [_PreviewView(preview: _preview)],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _AccountChoice extends StatelessWidget {
  const new({required this.entry, required this.selected, this.onTap});

  final RegisteredAccount entry;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    selected: selected,
    onTap: onTap,
    leading: AccountAvatar(entry: entry, radius: 20),
    title: Text(accountTitle(entry.account)),
    subtitle: Text(accountSubtitleOf(context.l10n, entry)),
    trailing: selected ? const Icon(Icons.check) : null,
  );
}

class _ListSection extends ConsumerWidget {
  const new({
    required this.accountId,
    required this.guest,
    required this.kind,
    required this.enabled,
    required this.onChoose,
    required this.onDays,
  });

  final String accountId;
  final bool guest;
  final WidgetKind kind;
  final bool enabled;
  final void Function(_ListChoice choice) onChoose;
  final void Function(int days) onDays;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // Read here, so the pickers have them when they open.
    final projects = ref.watch(widgetProjectChoicesProvider(accountId)).value;
    final labels = ref.watch(widgetLabelChoicesProvider(accountId)).value;
    final filters = guest
        ? null
        : ref.watch(widgetSavedFilterChoicesProvider(accountId)).value;
    final choose = l10n.widgetConfigureChoose;
    final selectedTitle = switch (kind) {
      ProjectTasksKind(:final projectId) =>
        projects
                ?.where((project) => project.id == projectId)
                .firstOrNull
                ?.displayTitle(l10n) ??
            l10n.widgetKindProject,
      LabelTasksKind(:final labelId) =>
        labels?.where((label) => label.id == labelId).firstOrNull?.title ??
            l10n.widgetKindLabel,
      SavedFilterKind(:final filterId) => switch (filters
          ?.where((filter) => filter.filterId == filterId)
          .firstOrNull) {
        final filter? => projectDisplayTitle(l10n, filter.title),
        null => l10n.widgetKindSavedFilter,
      },
      _ => null,
    };

    Widget tile(_ListChoice choice, WidgetKind sample, {String? subtitle}) {
      final selected = _choiceOf(kind) == choice;
      return ListTile(
        selected: selected,
        enabled: enabled,
        leading: Icon(widgetKindIcon(sample)),
        title: Text(widgetKindTitle(l10n, sample)),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: selected ? const Icon(Icons.check) : null,
        onTap: () => onChoose(choice),
      );
    }

    return SectionCard(
      title: l10n.widgetConfigureListHeading,
      children: [
        tile(
          _ListChoice.today,
          const TodayKind(),
          subtitle: l10n.widgetKindTodayHint,
        ),
        tile(
          _ListChoice.upcoming,
          const UpcomingKind(7),
          subtitle: l10n.widgetKindUpcomingHint,
        ),
        if (kind case UpcomingKind(:final days))
          _DaysChoice(days: days, enabled: enabled, onDays: onDays),
        tile(
          _ListChoice.overdue,
          const OverdueKind(),
          subtitle: l10n.widgetKindOverdueHint,
        ),
        tile(
          _ListChoice.favorites,
          const FavoritesKind(),
          subtitle: l10n.widgetKindFavoritesHint,
        ),
        tile(
          _ListChoice.project,
          const ProjectTasksKind(0),
          subtitle: kind is ProjectTasksKind ? selectedTitle : choose,
        ),
        tile(
          _ListChoice.label,
          const LabelTasksKind(0),
          subtitle: kind is LabelTasksKind ? selectedTitle : choose,
        ),
        if (!guest)
          tile(
            _ListChoice.savedFilter,
            const SavedFilterKind(0),
            subtitle: kind is SavedFilterKind ? selectedTitle : choose,
          ),
      ],
    );
  }

  static _ListChoice? _choiceOf(WidgetKind kind) => switch (kind) {
    TodayKind() => _ListChoice.today,
    UpcomingKind() => _ListChoice.upcoming,
    OverdueKind() => _ListChoice.overdue,
    FavoritesKind() => _ListChoice.favorites,
    ProjectTasksKind() => _ListChoice.project,
    LabelTasksKind() => _ListChoice.label,
    SavedFilterKind() => _ListChoice.savedFilter,
    QuickAddKind() => null,
  };
}

class _DaysChoice extends StatelessWidget {
  const new({required this.days, required this.enabled, required this.onDays});

  final int days;
  final bool enabled;
  final void Function(int days) onDays;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(72, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.widgetConfigureDaysLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in WidgetKind.upcomingDays)
                ChoiceChip(
                  label: Text(l10n.widgetUpcomingDays(option)),
                  selected: option == days,
                  onSelected: enabled ? (_) => onDays(option) : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _Choice {
  const new({
    required this.id,
    required this.title,
    this.depth = 0,
    this.leading,
  });

  final int id;
  final String title;
  final int depth;
  final Widget? leading;
}

class _ChoiceList extends StatelessWidget {
  const new({
    required this.title,
    required this.empty,
    required this.choices,
    required this.selectedId,
    required this.scrollController,
  });

  final String title;
  final String empty;
  final List<_Choice> choices;
  final int? selectedId;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      controller: scrollController,
      itemCount: choices.length + 1 + (choices.isEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Semantics(
              header: true,
              headingLevel: 1,
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
          );
        }
        if (choices.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Text(empty, style: theme.textTheme.bodyMedium),
          );
        }
        final choice = choices[index - 1];
        final selected = choice.id == selectedId;
        return ListTile(
          selected: selected,
          contentPadding: EdgeInsetsDirectional.only(
            start: 24 + 16.0 * choice.depth.clamp(0, 4),
            end: 24,
          ),
          leading: switch (choice.leading) {
            null => null,
            final leading => ExcludeSemantics(child: leading),
          },
          title: Text(choice.title),
          trailing: selected ? const Icon(Icons.check) : null,
          onTap: () => Navigator.of(context).pop(choice.id),
        );
      },
    );
  }
}

/// Roughly what the widget will show: its header with the count, the first
/// rows with their due labels, or what an empty list or a state says.
class _PreviewView extends StatelessWidget {
  const new({required this.preview});

  static const _rows = 5;

  final Future<WidgetSnapshot?>? preview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return FutureBuilder<WidgetSnapshot?>(
      future: preview,
      builder: (context, result) {
        if (result.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator.adaptive()),
          );
        }
        final snapshot = result.data;
        if (snapshot == null) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.widgetConfigurePreviewNone,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          );
        }
        final note = snapshot.state == WidgetSnapshotState.ok
            ? (snapshot.rows.isEmpty ? snapshot.empty : null)
            : snapshot.message;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      snapshot.title,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (snapshot.total > 0)
                    Semantics(
                      label: snapshot.countLabel,
                      excludeSemantics: snapshot.countLabel != null,
                      child: Text(
                        '${snapshot.total}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colors.primary,
                        ),
                      ),
                    ),
                ],
              ),
              if (snapshot.subtitle case final subtitle?)
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              if (note != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    [note.title, ?note.body].join('\n'),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              for (final row in snapshot.rows.take(_rows))
                _PreviewRow(row: row),
              // Its count is the snapshot's; the header has the total.
              if (snapshot.moreLabel case final more?
                  when snapshot.rows.length <= _rows)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    more,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const new({required this.row});

  final WidgetRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dueColor = switch (row.tone) {
      WidgetDueTone.overdue => colors.error,
      WidgetDueTone.today => colors.primary,
      WidgetDueTone.later || WidgetDueTone.none => colors.onSurfaceVariant,
    };
    return Semantics(
      label: row.semanticsLabel,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              row.canDone ? Icons.check_box_outline_blank : Icons.remove,
              size: 20,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (row.dueLabel case final due?)
                    Text(
                      due,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: dueColor,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
