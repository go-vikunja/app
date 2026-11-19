import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/router/pushed_pages.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/refreshable_list.dart';
import 'package:vikunja_mobile/features/common/presentation/screen_title.dart';
import 'package:vikunja_mobile/features/common/presentation/section_card.dart';
import 'package:vikunja_mobile/features/labels/application/label_groups.dart';
import 'package:vikunja_mobile/features/labels/presentation/label_change_failure.dart';
import 'package:vikunja_mobile/features/labels/presentation/label_color_dot.dart';
import 'package:vikunja_mobile/features/sync/application/offline_state.dart';
import 'package:vikunja_mobile/features/tasks/application/account_context_providers.dart';
import 'package:vikunja_mobile/features/tasks/application/label_providers.dart';
import 'package:vikunja_mobile/features/tasks/application/label_search.dart';
import 'package:vikunja_mobile/features/tasks/presentation/confirm_dialog.dart';

final _log = Logger('Labels');

enum _LabelAction { edit, delete }

/// The labels this device has, the user's own and, apart, those of other
/// people the user sees on shared tasks, by title. A label opens its open
/// tasks; only one's own labels can be edited or deleted. A new label, and
/// a change or delete of one the server does not have yet, works offline
/// and is marked until it is sent; the server's other labels are changed
/// and deleted online. Pulling down syncs.
class LabelsPage extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<LabelsPage> createState() => _LabelsPageState();
}

class _LabelsPageState extends ConsumerState<LabelsPage>
    with RefreshableList<LabelsPage> {
  final _query = TextEditingController();
  int? _busyLabelId;

  @override
  ProviderListenable<Object?> get repositoryProvider => labelRepositoryProvider;

  @override
  Future<void>? startRefresh() =>
      ref.read(projectRepositoryProvider)?.refresh();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _openTasks(Label label) =>
      unawaited(GoRouter.of(context).push(AppRoutes.labelTasks(label.id)));

  Future<void> _create() => context.pushPage<void>(AppRoutes.labelNew);

  Future<void> _edit(Label label) =>
      context.pushPage<void>(AppRoutes.labelEdit(label.id));

  Future<void> _delete(Label label) async {
    final repository = ref.read(labelRepositoryProvider);
    if (repository == null || _busyLabelId != null) return;
    final l10n = context.l10n;
    final confirmed = await confirmAdaptive(
      context,
      title: l10n.labelsDeleteTitle(label.title),
      body: l10n.labelsDeleteBody,
      confirmLabel: l10n.labelsDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busyLabelId = label.id);
    try {
      await repository.delete(label.id);
      if (!mounted) return;
      unawaited(HapticFeedback.selectionClick());
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.labelsDeleted)));
    } on Object catch (error) {
      _log.warning('Deleting a label failed: ${error.runtimeType}');
      unawaited(HapticFeedback.heavyImpact());
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(labelChangeFailureText(l10n, error))),
        );
    } finally {
      if (mounted) setState(() => _busyLabelId = null);
    }
  }

  void _onAction(Label label, _LabelAction action) =>
      unawaited(switch (action) {
        _LabelAction.edit => _edit(label),
        _LabelAction.delete => _delete(label),
      });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = ref.watch(allLabelsProvider);
    return Scaffold(
      appBar: AppBar(
        title: ScreenTitle(l10n.labelsTitle),
        actions: [RefreshButton(onPressed: refreshing ? null : refresh)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        // Every tab's top route stays below this page with its own button.
        heroTag: null,
        onPressed: () => unawaited(_create()),
        icon: const Icon(Icons.add),
        label: Text(l10n.labelsNew),
      ),
      body: buildRefreshable(
        labels,
        loadingLabel: l10n.labelsLoading,
        maxWidth: ReadableWidth.form,
        builder: (value, notice) => value.isEmpty
            ? CenteredScrollView(
                maxWidth: ReadableWidth.form,
                header: notice,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    EmptyState(
                      icon: Icons.label_outline,
                      title: l10n.labelsEmptyTitle,
                      body: l10n.labelsEmptyBody,
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => unawaited(_create()),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.labelsNew),
                    ),
                    // Clear of the floating button.
                    const SizedBox(height: 88),
                  ],
                ),
              )
            : _list(value, notice),
      ),
    );
  }

  Widget _list(List<Label> labels, Widget? notice) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final userId = ref.watch(activeUserIdProvider);
    final offline = ref.watch(offlineProvider) != null;
    final pending = ref.watch(pendingLabelIdsProvider).value ?? const {};
    final searchable = labels.length > labelSearchThreshold;
    final query = searchable ? _query.text : '';
    final shown = filterLabels(labels, query);
    final (:own, :others) = groupLabels(shown, userId: userId);
    final busy = _busyLabelId != null;

    Widget row(Label label, {required bool mine}) => _LabelRow(
      key: ValueKey(label.id),
      label: label,
      mine: mine,
      busy: _busyLabelId == label.id,
      enabled: !busy,
      pending: pending.contains(label.id),
      deletable: !offline || pending.contains(label.id),
      onTap: () => _openTasks(label),
      onAction: (action) => _onAction(label, action),
    );

    return ReadableWidth.builder(
      maxWidth: ReadableWidth.form,
      builder: (_, _, inset) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        // The page's context still carries the status bar, which the app bar
        // already takes.
        padding:
            MediaQuery.paddingOf(context).copyWith(top: 0) +
            EdgeInsets.fromLTRB(inset, 8, inset, 96),
        children: [
          if (notice != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: notice,
            ),
          if (searchable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: TextField(
                controller: _query,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: l10n.labelsSearch,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l10n.clearSearch,
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(_query.clear),
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  l10n.labelsSearchEmpty(query.trim()),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          if (own.isNotEmpty)
            SectionCard(
              title: l10n.labelsOwnSection,
              count: own.length,
              children: [for (final label in own) row(label, mine: true)],
            ),
          if (others.isNotEmpty)
            SectionCard(
              title: l10n.labelsOthersSection,
              count: others.length,
              children: [for (final label in others) row(label, mine: false)],
            ),
        ],
      ),
    );
  }
}

class _LabelRow extends StatelessWidget {
  const new({
    required this.label,
    required this.mine,
    required this.busy,
    required this.enabled,
    required this.pending,
    required this.deletable,
    required this.onTap,
    required this.onAction,
    super.key,
  });

  final Label label;
  final bool mine;

  /// A change of this label is on its way.
  final bool busy;

  /// False while a change of any label is on its way.
  final bool enabled;

  /// The server does not have it, or a change of it, yet.
  final bool pending;

  /// Off while offline for a label the server has with nothing of it
  /// queued, as its delete goes to the server at once; the form says it is
  /// offline itself.
  final bool deletable;
  final VoidCallback onTap;
  final ValueChanged<_LabelAction> onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final title = label.title.trim().isEmpty ? '–' : label.title;
    final description = descriptionFirstLine(label.description);
    final creator = label.createdBy;
    final lines = [
      if (description.isNotEmpty) description,
      if (!mine && creator != null) l10n.labelsCreatedBy(creator.displayName),
    ];
    return ListTile(
      leading: SizedBox(
        width: 24,
        child: Center(child: LabelColorDot(hexColor: label.hexColor)),
      ),
      title: pending
          ? Row(
              children: [
                Flexible(child: Text(title)),
                const SizedBox(width: 6),
                Icon(
                  Icons.cloud_off_outlined,
                  size: 16,
                  color: colors.onSurfaceVariant,
                  semanticLabel: l10n.taskNotYetSynced,
                ),
              ],
            )
          : Text(title),
      subtitle: lines.isEmpty
          ? null
          : Text(
              lines.join('\n'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
      onTap: onTap,
      trailing: !mine
          ? null
          : busy
          ? SizedBox.square(
              dimension: kMinInteractiveDimension,
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    semanticsLabel: l10n.labelsSaving,
                  ),
                ),
              ),
            )
          : PopupMenuButton<_LabelAction>(
              tooltip: l10n.labelsOptionsFor(title),
              enabled: enabled,
              icon: const Icon(Icons.more_vert),
              onSelected: onAction,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _LabelAction.edit,
                  child: IgnorePointer(
                    child: ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: Text(l10n.labelsEdit),
                    ),
                  ),
                ),
                PopupMenuItem(
                  value: _LabelAction.delete,
                  enabled: deletable,
                  child: IgnorePointer(
                    child: ListTile(
                      enabled: deletable,
                      leading: Icon(
                        Icons.delete_outline,
                        color: deletable ? colors.error : null,
                      ),
                      title: Text(
                        l10n.labelsDelete,
                        style: TextStyle(
                          color: deletable ? colors.error : null,
                        ),
                      ),
                      subtitle: deletable
                          ? null
                          : Text(l10n.labelsNeedsConnection),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
