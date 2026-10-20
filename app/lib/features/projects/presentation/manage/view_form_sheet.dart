import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/repositories/project_view_repository_providers.dart';
import 'package:vikunja_mobile/features/common/presentation/option_sheet.dart';
import 'package:vikunja_mobile/features/projects/application/project_management.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/form_parts.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/project_change_failure.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/view_labels.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/picker_sheet.dart';

final _log = Logger('ViewForm');

/// A new view of [projectId], or [view] edited; [onSaved] once the server
/// took it.
Future<void> showViewFormSheet(
  BuildContext context, {
  required int projectId,
  required VoidCallback onSaved,
  ProjectView? view,
}) => showPickerSheet<void>(
  context,
  builder: (context, scrollController) => ViewFormSheet(
    projectId: projectId,
    view: view,
    onSaved: onSaved,
    scrollController: scrollController,
  ),
);

/// The web's view form without its autocomplete: title, kind and filter in
/// the web's syntax, which the server checks; for a list the web's default
/// `done = false` as a switch, for a board whether its columns are its own
/// or come from filters, whose setup stays on the web. Save waits for the
/// server, closes and calls [onSaved], also when the sheet was dragged shut
/// meanwhile; a refusal then comes in a snackbar.
class ViewFormSheet extends ConsumerStatefulWidget {
  const new({
    required this.projectId,
    required this.onSaved,
    this.view,
    this.scrollController,
    super.key,
  });

  final int projectId;
  final VoidCallback onSaved;
  final ProjectView? view;
  final ScrollController? scrollController;

  @override
  ConsumerState<ViewFormSheet> createState() => _ViewFormSheetState();
}

class _ViewFormSheetState extends ConsumerState<ViewFormSheet> {
  late final _title = TextEditingController(text: widget.view?.title ?? '');
  late final _filter = TextEditingController();
  late ProjectViewKind _kind = widget.view?.kind ?? ProjectViewKind.list;
  var _showDone = false;
  late BucketConfigurationMode _mode =
      widget.view?.bucketConfigurationMode == BucketConfigurationMode.filter
      ? BucketConfigurationMode.filter
      : BucketConfigurationMode.manual;
  var _filterTouched = false;
  var _filterEdited = false;
  var _titleEdited = false;
  var _saving = false;
  String? _filterError;
  String? _error;

  @override
  void initState() {
    super.initState();
    final text = widget.view?.filter?.filter.trim() ?? '';
    if (_kind == ProjectViewKind.list) {
      final parts = widget.view == null
          ? (showDone: false, rest: '')
          : splitListFilter(text);
      _showDone = parts.showDone;
      _filter.text = parts.rest;
    } else {
      _filter.text = text;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _filter.dispose();
    super.dispose();
  }

  String get _filterText => _kind == ProjectViewKind.list
      ? joinListFilter((showDone: _showDone, rest: _filter.text))
      : _filter.text.trim();

  /// The switch of a list stands for part of the filter, so the text
  /// changes with the kind. A new view the user has not filtered yet takes
  /// the kind's default: the web's `done = false` for a list, none else.
  void _setKind(ProjectViewKind kind) {
    if (kind == _kind) return;
    final text = widget.view != null || _filterEdited
        ? _filterText
        : kind == ProjectViewKind.list
        ? 'done = false'
        : '';
    setState(() {
      _kind = kind;
      _filterTouched = true;
      _filterError = null;
      if (kind == ProjectViewKind.list) {
        final parts = splitListFilter(text);
        _showDone = parts.showDone;
        _filter.text = parts.rest;
      } else {
        _filter.text = text;
      }
    });
  }

  /// The original filter while it was left alone, so that its search and
  /// sort and its own spelling stay.
  ViewFilter? _viewFilter() {
    final original = widget.view?.filter;
    if (widget.view != null && !_filterTouched) return original;
    final text = _filterText;
    if (original != null && text == original.filter.trim()) return original;
    final search = original?.search ?? '';
    if (text.isEmpty && search.trim().isEmpty) return null;
    return ViewFilter(
      filter: text,
      search: search,
      sortBy: original?.sortBy ?? const [],
      orderBy: original?.orderBy ?? const [],
      includeNulls: original?.includeNulls ?? false,
    );
  }

  Future<void> _chooseKind() async {
    final l10n = context.l10n;
    final kind = await showOptionSheet<ProjectViewKind>(
      context,
      title: l10n.projectViewKindLabel,
      options: [
        for (final kind in ProjectViewKind.values)
          SheetOption(
            value: kind,
            label: viewKindOptionLabel(l10n, kind),
            selected: kind == _kind,
          ),
      ],
    );
    if (kind != null && mounted) _setKind(kind);
  }

  Future<void> _chooseMode() async {
    final l10n = context.l10n;
    final mode = await showOptionSheet<BucketConfigurationMode>(
      context,
      title: l10n.projectViewColumnsLabel,
      options: [
        for (final mode in const [
          BucketConfigurationMode.manual,
          BucketConfigurationMode.filter,
        ])
          SheetOption(
            value: mode,
            label: bucketModeLabel(l10n, mode),
            selected: mode == _mode,
          ),
      ],
    );
    if (mode != null && mounted) setState(() => _mode = mode);
  }

  Future<void> _save() async {
    final repository = ref.read(projectViewRepositoryProvider);
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleEdited = true);
      return;
    }
    if (repository == null || _saving) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final onSaved = widget.onSaved;
    final draft = ViewDraft(
      title: title,
      kind: _kind,
      filter: _viewFilter(),
      bucketConfigurationMode: _kind == ProjectViewKind.kanban ? _mode : null,
    );
    setState(() {
      _saving = true;
      _error = null;
      _filterError = null;
    });
    try {
      final view = widget.view;
      if (view == null) {
        await repository.createView(widget.projectId, draft);
      } else {
        await repository.updateView(widget.projectId, view.id, draft);
      }
      if (mounted) Navigator.of(context).pop();
      onSaved();
    } on Object catch (error) {
      _log.warning('Saving a view failed: ${error.runtimeType}');
      unawaited(HapticFeedback.heavyImpact());
      final text = projectChangeFailureText(l10n, error, ProjectChange.view);
      if (!mounted) {
        showFailureAfterClose(messenger, text);
        return;
      }
      final invalidFilter = isInvalidViewFilter(error);
      setState(() {
        _saving = false;
        if (invalidFilter) {
          _filterError = text;
        } else {
          _error = text;
        }
      });
      // The field lost its focus while disabled, and an error text is a
      // live region only where the platform cannot announce.
      if (invalidFilter) {
        unawaited(
          SemanticsService.sendAnnouncement(
            View.of(context),
            text,
            Directionality.of(context),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final editing = widget.view != null;
    final emptyTitle = _title.text.trim().isEmpty;
    return PopScope(
      canPop: !_saving,
      child: SingleChildScrollView(
        controller: widget.scrollController,
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PickerHeader(
              title: editing ? l10n.projectViewEditTitle : l10n.projectViewNew,
              actionLabel: _saving
                  ? l10n.projectSaving
                  : editing
                  ? l10n.projectSave
                  : l10n.projectCreate,
              onAction: emptyTitle || _saving ? null : () => unawaited(_save()),
            ),
            if (_saving) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _title,
                autofocus: !editing,
                enabled: !_saving,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  CodePointLimitFormatter(projectTitleMaxLength),
                ],
                decoration: InputDecoration(
                  labelText: l10n.projectTitleLabel,
                  errorText: _titleEdited && emptyTitle
                      ? l10n.projectTitleRequired
                      : null,
                  errorMaxLines: 3,
                ),
                onChanged: (_) => setState(() => _titleEdited = true),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              enabled: !_saving,
              leading: Icon(
                viewKindIcon(_kind),
                color: colors.onSurfaceVariant,
              ),
              title: Text(l10n.projectViewKindLabel),
              subtitle: Text(viewKindOptionLabel(l10n, _kind)),
              trailing: const Icon(Icons.arrow_drop_down),
              onTap: () => unawaited(_chooseKind()),
            ),
            if (_kind == ProjectViewKind.list)
              SwitchListTile.adaptive(
                value: _showDone,
                onChanged: _saving
                    ? null
                    : (value) => setState(() {
                        _showDone = value;
                        _filterTouched = true;
                        _filterEdited = true;
                        _filterError = null;
                      }),
                title: Text(l10n.projectViewShowDone),
                subtitle: Text(l10n.projectViewShowDoneHint),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _filter,
                enabled: !_saving,
                // Wraps, but Return confirms instead of adding a line.
                maxLines: null,
                keyboardType: TextInputType.text,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l10n.projectViewFilterLabel,
                  hintText: l10n.projectViewFilterHint,
                  helperText: l10n.projectViewFilterHelp,
                  helperMaxLines: 6,
                  errorText: _filterError,
                  errorMaxLines: 8,
                ),
                onChanged: (_) => setState(() {
                  _filterTouched = true;
                  _filterEdited = true;
                  _filterError = null;
                }),
              ),
            ),
            if (_kind == ProjectViewKind.kanban) ...[
              const SizedBox(height: 8),
              ListTile(
                enabled: !_saving,
                leading: Icon(
                  Icons.view_column_outlined,
                  color: colors.onSurfaceVariant,
                ),
                title: Text(l10n.projectViewColumnsLabel),
                subtitle: Text(bucketModeLabel(l10n, _mode)),
                trailing: const Icon(Icons.arrow_drop_down),
                onTap: () => unawaited(_chooseMode()),
              ),
              if (_mode == BucketConfigurationMode.filter)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    l10n.projectViewFilterColumnsOnWeb,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
            if (_error case final error?) FormErrorText(error),
          ],
        ),
      ),
    );
  }
}
