import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/loading_placeholder.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/form_parts.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/parent_picker.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/project_change_failure.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/project_confirmations.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/color_row.dart';

final _log = Logger('ProjectEdit');

/// Title, identifier, colour and parent of a project. Save sends only what
/// differs from the project as it was when the page opened, waits for the
/// server and stays open with the reason when it refuses. The description
/// is rich text, left to the web until the app has an editor for it.
class ProjectEditPage extends ConsumerStatefulWidget {
  const new({required this.projectId, super.key});

  final int projectId;

  @override
  ConsumerState<ProjectEditPage> createState() => _ProjectEditPageState();
}

class _ProjectEditPageState extends ConsumerState<ProjectEditPage> {
  final _title = TextEditingController();
  final _identifier = TextEditingController();
  Project? _original;
  var _hexColor = '';
  var _parentId = 0;
  var _saving = false;
  var _saved = false;
  String? _identifierError;

  @override
  void dispose() {
    _title.dispose();
    _identifier.dispose();
    super.dispose();
  }

  void _adopt(Project? project) {
    if (project == null || _original != null) return;
    _original = project;
    // The raw title: the translated display title of an "Inbox" is no
    // title to store.
    _title.text = project.title;
    _identifier.text = project.identifier;
    _hexColor = project.hexColor;
    _parentId = project.parentProjectId;
  }

  ProjectChanges _changes(Project original) {
    final title = _title.text == original.title ? null : _title.text.trim();
    final identifier = _identifier.text == original.identifier
        ? null
        : _identifier.text.trim();
    return ProjectChanges(
      title: title == original.title ? null : title,
      identifier: identifier == original.identifier ? null : identifier,
      hexColor: _hexColor == original.hexColor ? null : _hexColor,
      parentProjectId: _parentId == original.parentProjectId ? null : _parentId,
    );
  }

  bool get _dirty {
    final original = _original;
    return original != null && !_changes(original).isEmpty;
  }

  /// The server checks the stored title on every change, so a title over
  /// the limit, as a duplicate's can be, blocks saving anything else too.
  bool get _titleTooLong =>
      _title.text.trim().runes.length > projectTitleMaxLength;

  bool get _canSave =>
      _dirty && _title.text.trim().isNotEmpty && !_titleTooLong && !_saving;

  Future<void> _pickParent() async {
    final projects = ref.read(projectsProvider).value ?? const <Project>[];
    final picked = await pickParentProject(
      context,
      projects: projects,
      selectedId: _parentId,
      movedProjectId: widget.projectId,
    );
    if (picked != null && mounted) setState(() => _parentId = picked);
  }

  Future<void> _save() async {
    final repository = ref.read(projectRepositoryProvider);
    final original = _original;
    if (repository == null || original == null || !_canSave) return;
    final changes = _changes(original);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() {
      _saving = true;
      _identifierError = null;
    });
    try {
      await repository.updateProject(original.id, changes);
      if (!mounted) return;
      setState(() => _saved = true);
      router.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.projectEditSaved)));
    } on Object catch (error) {
      _log.warning('Saving a project failed: ${error.runtimeType}');
      unawaited(HapticFeedback.heavyImpact());
      if (!mounted) return;
      setState(() => _saving = false);
      if (error case VikunjaFailure(code: 3007)) {
        setState(() => _identifierError = l10n.projectIdentifierTaken);
        unawaited(
          SemanticsService.sendAnnouncement(
            View.of(context),
            l10n.projectIdentifierTaken,
            Directionality.of(context),
          ),
        );
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              projectChangeFailureText(
                l10n,
                error,
                changes.parentProjectId == null
                    ? ProjectChange.edit
                    : ProjectChange.editWithParent,
              ),
            ),
          ),
        );
    }
  }

  Future<void> _leaveIfConfirmed() async {
    final router = GoRouter.of(context);
    if (await confirmDiscardProjectChanges(context) && mounted) router.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final projects = ref.watch(projectsProvider);
    final all = projects.value ?? const <Project>[];
    final project = all.where((p) => p.id == widget.projectId).firstOrNull;
    if (projects.hasValue) _adopt(project);
    final original = _original;

    return PopScope(
      canPop: _saved || (!_dirty && !_saving),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) unawaited(_leaveIfConfirmed());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.projectEditTitle),
          actions: [
            TextButton(
              onPressed: _canSave ? () => unawaited(_save()) : null,
              child: Text(_saving ? l10n.projectSaving : l10n.projectSave),
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
        body: switch ((original, projects.hasValue)) {
          (_?, _) when project != null || _saving || _saved => _Form(
            titleController: _title,
            titleTooLong: _titleTooLong,
            identifierController: _identifier,
            identifierError: _identifierError,
            hexColor: _hexColor,
            parentLabel: parentProjectLabel(l10n, _parentId, all),
            enabled: !_saving,
            onChanged: () => setState(() {}),
            onIdentifierChanged: () => setState(() => _identifierError = null),
            onColorChanged: (hex) => setState(() => _hexColor = hex),
            onPickParent: () => unawaited(_pickParent()),
          ),
          (_, true) => CenteredScrollView(
            child: EmptyState(
              icon: Icons.search_off,
              title: l10n.projectGoneTitle,
              body: l10n.projectGoneBody,
            ),
          ),
          _ => CenteredScrollView(
            child: LoadingPlaceholder(label: l10n.projectsLoading),
          ),
        },
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const new({
    required this.titleController,
    required this.titleTooLong,
    required this.identifierController,
    required this.identifierError,
    required this.hexColor,
    required this.parentLabel,
    required this.enabled,
    required this.onChanged,
    required this.onIdentifierChanged,
    required this.onColorChanged,
    required this.onPickParent,
  });

  final TextEditingController titleController;
  final bool titleTooLong;
  final TextEditingController identifierController;
  final String? identifierError;
  final String hexColor;
  final String parentLabel;
  final bool enabled;
  final VoidCallback onChanged;
  final VoidCallback onIdentifierChanged;
  final ValueChanged<String> onColorChanged;
  final VoidCallback onPickParent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasTitle = titleController.text.trim().isNotEmpty;
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: titleController,
            enabled: enabled,
            // Wraps, but Return moves on instead of adding a line.
            maxLines: null,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [CodePointLimitFormatter(projectTitleMaxLength)],
            decoration: InputDecoration(
              labelText: l10n.projectTitleLabel,
              errorText: !hasTitle
                  ? l10n.projectTitleRequired
                  : titleTooLong
                  ? l10n.projectTitleTooLong
                  : null,
              errorMaxLines: 3,
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: identifierController,
            enabled: enabled,
            maxLength: projectIdentifierMaxLength,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              _UpperCaseFormatter(),
              CodePointLimitFormatter(projectIdentifierMaxLength),
            ],
            decoration: InputDecoration(
              labelText: l10n.projectIdentifierLabel,
              helperText: l10n.projectIdentifierHelp,
              helperMaxLines: 6,
              errorText: identifierError,
              errorMaxLines: 4,
            ),
            onChanged: (_) {
              onIdentifierChanged();
              onChanged();
            },
          ),
        ),
        const SizedBox(height: 8),
        ParentProjectTile(
          label: parentLabel,
          onTap: enabled ? onPickParent : null,
        ),
        FormSectionTitle(l10n.taskEditColour),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: IgnorePointer(
            ignoring: !enabled,
            child: ColorRow(value: hexColor, onChanged: onColorChanged),
          ),
        ),
      ],
    );
  }
}

/// The server stores identifiers upper-case; typing them so shows what
/// will be kept.
final class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.toUpperCase();
    if (text == newValue.text) return newValue;
    if (text.length == newValue.text.length) {
      return newValue.copyWith(text: text);
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
