import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/repositories/saved_filter_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/text/html_to_text.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/form_parts.dart';
import 'package:vikunja_mobile/features/common/presentation/loading_placeholder.dart';
import 'package:vikunja_mobile/features/filters/presentation/filter_field.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/form_parts.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/project_confirmations.dart';
import 'package:vikunja_mobile/features/smart_lists/application/smart_list_providers.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/saved_filter_failure.dart';

final _log = Logger('SavedFilterForm');

/// What a saved filter's form starts from.
typedef _Start = ({
  String title,
  String description,
  ViewFilter filter,
  bool isFavorite,
  String timezone,
});

/// A new web default: open tasks, tasks without a value included, done
/// last and newest first.
const _newFilter = ViewFilter(
  filter: 'done = false',
  sortBy: ['done', 'id'],
  orderBy: ['asc', 'desc'],
  includeNulls: true,
);

/// A new saved filter ([pseudoProjectId] null), or one edited: title,
/// description, the filter with the builder, whether tasks without a value
/// count, and the favourite. Save waits for the server and stays open with
/// the reason when it refuses; a new one opens once created. The stored
/// search and sort, which the form does not show, stay as they are.
class SavedFilterFormPage extends ConsumerStatefulWidget {
  const new({this.pseudoProjectId, super.key});

  final int? pseudoProjectId;

  @override
  ConsumerState<SavedFilterFormPage> createState() =>
      _SavedFilterFormPageState();
}

class _SavedFilterFormPageState extends ConsumerState<SavedFilterFormPage> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  _Start? _start;
  var _filter = const FilterInput(apiText: '');
  var _includeNulls = false;
  var _favourite = false;
  var _saving = false;
  var _saved = false;
  String? _filterError;

  /// The definition read from the server where none is stored here.
  Future<SavedFilter>? _reading;

  bool get _isNew => widget.pseudoProjectId == null;

  @override
  void initState() {
    super.initState();
    if (_isNew) {
      _adopt((
        title: '',
        description: '',
        filter: _newFilter,
        isFavorite: false,
        timezone: '',
      ));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _adopt(_Start start) {
    if (_start != null) return;
    _start = start;
    _title.text = start.title;
    _description.text = _plainDescription(start);
    _filter = FilterInput(apiText: start.filter.filter.trim());
    _includeNulls = start.filter.includeNulls;
    _favourite = start.isFavorite;
  }

  void _read(int pseudoProjectId) {
    final repository = ref.read(savedFilterRepositoryProvider);
    if (repository == null) return;
    final reading = repository.read(pseudoProjectId);
    setState(() {
      _reading = reading;
    });
  }

  /// The web edits the description as rich text; the form shows its text.
  static String _plainDescription(_Start start) =>
      htmlToPlainText(start.description);

  bool get _dirty {
    final start = _start;
    if (start == null) return false;
    return _title.text != start.title ||
        _description.text != _plainDescription(start) ||
        _filter.apiText != start.filter.filter.trim() ||
        _includeNulls != start.filter.includeNulls ||
        _favourite != start.isFavorite;
  }

  bool get _filterMissing => _filter.apiText.trim().isEmpty;

  bool get _canSave =>
      _start != null &&
      (_isNew || _dirty) &&
      _title.text.trim().isNotEmpty &&
      !_filterMissing &&
      !_filter.blocksSaving &&
      !_saving;

  SavedFilterDraft _draft(_Start start) => SavedFilterDraft(
    title: _title.text.trim(),
    // Untouched, the stored rich text goes back as it was.
    description: _description.text == _plainDescription(start)
        ? start.description
        : plainTextToHtml(_description.text.trim()),
    filter: ViewFilter(
      filter: _filter.apiText.trim(),
      search: start.filter.search,
      sortBy: start.filter.sortBy,
      orderBy: start.filter.orderBy,
      includeNulls: _includeNulls,
    ),
    isFavorite: _favourite,
  );

  void _filterChanged(FilterInput input) => setState(() {
    if (input.apiText != _filter.apiText) _filterError = null;
    _filter = input;
  });

  Future<void> _save() async {
    final repository = ref.read(savedFilterRepositoryProvider);
    final start = _start;
    if (repository == null || start == null || !_canSave) return;
    final draft = _draft(start);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() {
      _saving = true;
      _filterError = null;
    });
    try {
      final pseudoProjectId = widget.pseudoProjectId;
      if (pseudoProjectId == null) {
        final created = await repository.create(draft);
        if (!mounted) return;
        setState(() => _saved = true);
        router.go(AppRoutes.project(created));
      } else {
        await repository.update(pseudoProjectId, draft);
        if (!mounted) return;
        setState(() => _saved = true);
        router.pop();
      }
      unawaited(HapticFeedback.selectionClick());
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _isNew ? l10n.savedFilterCreated : l10n.savedFilterSaved,
            ),
          ),
        );
    } on Object catch (error) {
      _log.warning('Saving a saved filter failed: ${error.runtimeType}');
      unawaited(HapticFeedback.heavyImpact());
      if (!mounted) return;
      final text = savedFilterFailureText(l10n, error, fromForm: true);
      setState(() => _saving = false);
      if (isInvalidSavedFilter(error)) {
        setState(() => _filterError = text);
        // The field lost its focus while disabled.
        unawaited(
          SemanticsService.sendAnnouncement(
            View.of(context),
            text,
            Directionality.of(context),
          ),
        );
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _leaveIfConfirmed() async {
    final router = GoRouter.of(context);
    if (await confirmDiscardChanges(
          context,
          body: context.l10n.savedFilterEditDiscardBody,
        ) &&
        mounted) {
      router.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final body = _isNew ? _form(context) : _editBody(context);
    return PopScope(
      canPop: _saved || (!_dirty && !_saving),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) unawaited(_leaveIfConfirmed());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? l10n.savedFilterNew : l10n.savedFilterEditTitle),
          actions: [
            TextButton(
              onPressed: _canSave ? () => unawaited(_save()) : null,
              child: Text(
                _saving
                    ? l10n.projectSaving
                    : _isNew
                    ? l10n.projectCreate
                    : l10n.projectSave,
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
        body: body,
      ),
    );
  }

  /// The stored saved filter, its definition read from the server when
  /// this device does not know it.
  Widget _editBody(BuildContext context) {
    final l10n = context.l10n;
    final pseudoProjectId = widget.pseudoProjectId!;
    final filters = ref.watch(savedFiltersProvider);
    final listed = filters.value
        ?.where((filter) => filter.projectId == pseudoProjectId)
        .firstOrNull;
    if (_start == null) {
      if (listed?.definition case final definition?) {
        _adopt(_startOf(listed!, definition));
      } else if (listed != null && _reading == null) {
        // Within this build, so the loading state shows at once.
        _reading = ref
            .read(savedFilterRepositoryProvider)
            ?.read(pseudoProjectId);
      }
    }
    if (_start != null) return _form(context);
    if (filters.hasValue && listed == null) {
      return CenteredScrollView(
        child: EmptyState(
          icon: Icons.filter_list_off,
          title: l10n.smartListFilterGoneTitle,
          body: l10n.smartListFilterGoneBody,
        ),
      );
    }
    final reading = _reading;
    if (reading == null) {
      return CenteredScrollView(
        child: LoadingPlaceholder(label: l10n.savedFilterLoading),
      );
    }
    return FutureBuilder<SavedFilter>(
      future: reading,
      builder: (context, snapshot) {
        if (snapshot.data case final read?) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _start != null) return;
            setState(
              () => _adopt((
                title: read.title,
                description: read.description,
                filter: read.filter,
                isFavorite: read.isFavorite,
                timezone: read.timezone,
              )),
            );
          });
        }
        if (snapshot.error case final error?) {
          return CenteredScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: l10n.savedFilterLoadFailed,
                  body: savedFilterFailureText(l10n, error, fromForm: true),
                ),
                FilledButton.tonal(
                  onPressed: () => _read(pseudoProjectId),
                  child: Text(l10n.retry),
                ),
              ],
            ),
          );
        }
        return CenteredScrollView(
          child: LoadingPlaceholder(label: l10n.savedFilterLoading),
        );
      },
    );
  }

  static _Start _startOf(SavedFilterRef listed, SavedFilterDefinition known) =>
      (
        title: listed.title,
        description: listed.description,
        filter: known.filter,
        isFavorite: listed.isFavorite,
        timezone: known.timezone,
      );

  Widget _form(BuildContext context) {
    final l10n = context.l10n;
    final start = _start!;
    final enabled = !_saving;
    final hasTitle = _title.text.trim().isNotEmpty;
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _title,
            enabled: enabled,
            autofocus: _isNew,
            // Wraps, but Return moves on instead of adding a line.
            maxLines: null,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [CodePointLimitFormatter(projectTitleMaxLength)],
            decoration: InputDecoration(
              labelText: l10n.projectTitleLabel,
              errorText: !hasTitle && (_dirty || !_isNew)
                  ? l10n.projectTitleRequired
                  : null,
              errorMaxLines: 3,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _description,
            enabled: enabled,
            minLines: 2,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.savedFilterDescriptionLabel,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 16),
        FilterField(
          initialFilter: start.filter.filter,
          includeNulls: _includeNulls,
          search: start.filter.search,
          timezone: start.timezone,
          enabled: enabled,
          serverError:
              _filterError ??
              (_filter.edited && _filterMissing
                  ? l10n.savedFilterFilterRequired
                  : null),
          onChanged: _filterChanged,
        ),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          value: _includeNulls,
          onChanged: enabled
              ? (value) => setState(() => _includeNulls = value)
              : null,
          title: Text(l10n.savedFilterIncludeNulls),
          subtitle: Text(l10n.savedFilterIncludeNullsHint),
        ),
        SwitchListTile.adaptive(
          value: _favourite,
          onChanged: enabled
              ? (value) => setState(() => _favourite = value)
              : null,
          title: Text(l10n.savedFilterFavourite),
          subtitle: Text(l10n.savedFilterFavouriteHint),
        ),
      ],
    );
  }
}
