import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/common/presentation/form_parts.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/form_parts.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/parent_picker.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/project_change_failure.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/color_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/picker_sheet.dart';

final _log = Logger('NewProject');

/// Asks for a new project under [parentProjectId] (0: the top level),
/// creates it online and opens it.
Future<void> createProjectAndOpen(
  BuildContext context, {
  int parentProjectId = 0,
}) async {
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  await showPickerSheet<void>(
    context,
    builder: (context, scrollController) => NewProjectSheet(
      parentProjectId: parentProjectId,
      scrollController: scrollController,
      onCreated: (projectId) {
        router.go(AppRoutes.project(projectId));
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.projectCreated)));
      },
    ),
  );
}

/// Title, parent and colour of a new project, as on the web; Create waits
/// for the server, closes and calls [onCreated] with the new project's id,
/// a refusal stays in the sheet. The sheet can be dragged shut while it
/// waits: the project is then opened all the same, or the refusal said in
/// a snackbar.
class NewProjectSheet extends ConsumerStatefulWidget {
  const new({
    required this.onCreated,
    this.parentProjectId = 0,
    this.scrollController,
    super.key,
  });

  final ValueChanged<int> onCreated;
  final int parentProjectId;
  final ScrollController? scrollController;

  @override
  ConsumerState<NewProjectSheet> createState() => _NewProjectSheetState();
}

class _NewProjectSheetState extends ConsumerState<NewProjectSheet> {
  final _title = TextEditingController();
  late int _parentId = widget.parentProjectId;
  var _hexColor = '';
  var _edited = false;
  var _creating = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  String get _trimmed => _title.text.trim();

  Future<void> _pickParent() async {
    final projects = ref.read(projectsProvider).value ?? const <Project>[];
    final picked = await pickParentProject(
      context,
      projects: projects,
      selectedId: _parentId,
    );
    if (picked != null && mounted) setState(() => _parentId = picked);
  }

  Future<void> _create() async {
    final repository = ref.read(projectRepositoryProvider);
    final title = _trimmed;
    if (title.isEmpty) {
      setState(() => _edited = true);
      return;
    }
    if (repository == null || _creating) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final onCreated = widget.onCreated;
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final projectId = await repository.createProject(
        NewProject(
          title: title,
          parentProjectId: _parentId,
          hexColor: _hexColor,
        ),
      );
      if (mounted) Navigator.of(context).pop();
      onCreated(projectId);
    } on Object catch (error) {
      _log.warning('Creating a project failed: ${error.runtimeType}');
      unawaited(HapticFeedback.heavyImpact());
      final text = projectChangeFailureText(l10n, error, ProjectChange.create);
      if (!mounted) {
        showFailureAfterClose(messenger, text);
        return;
      }
      setState(() {
        _creating = false;
        _error = text;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final empty = _trimmed.isEmpty;
    return PopScope(
      canPop: !_creating,
      child: SingleChildScrollView(
        controller: widget.scrollController,
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PickerHeader(
              title: l10n.projectNew,
              actionLabel: _creating
                  ? l10n.projectCreating
                  : l10n.projectCreate,
              onAction: empty || _creating ? null : () => unawaited(_create()),
            ),
            if (_creating) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _title,
                autofocus: true,
                enabled: !_creating,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  CodePointLimitFormatter(projectTitleMaxLength),
                ],
                decoration: InputDecoration(
                  labelText: l10n.projectTitleLabel,
                  hintText: l10n.projectTitleHint,
                  errorText: _edited && empty
                      ? l10n.projectTitleRequired
                      : null,
                  errorMaxLines: 3,
                ),
                onChanged: (_) => setState(() => _edited = true),
                onSubmitted: (_) => unawaited(_create()),
              ),
            ),
            const SizedBox(height: 8),
            ParentProjectTile(
              label: parentProjectLabel(l10n, _parentId, projects),
              onTap: _creating ? null : () => unawaited(_pickParent()),
            ),
            FormSectionTitle(l10n.taskEditColour),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: IgnorePointer(
                ignoring: _creating,
                child: ColorRow(
                  value: _hexColor,
                  onChanged: (hex) => setState(() => _hexColor = hex),
                ),
              ),
            ),
            if (_error case final error?) FormErrorText(error),
          ],
        ),
      ),
    );
  }
}
