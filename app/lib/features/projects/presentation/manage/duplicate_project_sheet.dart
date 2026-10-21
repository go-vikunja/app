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
import 'package:vikunja_mobile/features/projects/application/project_management.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/form_parts.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/parent_picker.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/project_change_failure.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/picker_sheet.dart';

final _log = Logger('DuplicateProject');

/// Asks where the copy of [project] goes and whether its shares come
/// along, duplicates it and opens the copy once its tasks are stored.
Future<void> duplicateProjectAndOpen(
  BuildContext context, {
  required Project project,
}) async {
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  await showPickerSheet<void>(
    context,
    builder: (context, scrollController) => DuplicateProjectSheet(
      project: project,
      scrollController: scrollController,
      onDuplicated: (copyId) {
        router.go(AppRoutes.project(copyId));
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.projectDuplicated)));
      },
    ),
  );
}

/// Duplicate waits for the server and a sync, closes and calls
/// [onDuplicated] with the copy's id, also when the sheet was dragged shut
/// meanwhile; a refusal then comes in a snackbar.
class DuplicateProjectSheet extends ConsumerStatefulWidget {
  const new({
    required this.project,
    required this.onDuplicated,
    this.scrollController,
    super.key,
  });

  final Project project;
  final ValueChanged<int> onDuplicated;
  final ScrollController? scrollController;

  @override
  ConsumerState<DuplicateProjectSheet> createState() =>
      _DuplicateProjectSheetState();
}

class _DuplicateProjectSheetState extends ConsumerState<DuplicateProjectSheet> {
  late int _parentId = _initialParent();
  var _copyShares = true;
  var _duplicating = false;
  String? _error;

  /// The source's parent, as on the web, unless it cannot hold the copy.
  int _initialParent() {
    final parentId = widget.project.parentProjectId;
    final projects = ref.read(projectsProvider).value ?? const <Project>[];
    final candidate = parentCandidates(projects)
        .any((row) => row.node.project.id == parentId);
    return candidate ? parentId : 0;
  }

  Future<void> _pickParent() async {
    final projects = ref.read(projectsProvider).value ?? const <Project>[];
    final picked = await pickParentProject(
      context,
      projects: projects,
      selectedId: _parentId,
    );
    if (picked != null && mounted) setState(() => _parentId = picked);
  }

  Future<void> _duplicate() async {
    final repository = ref.read(projectRepositoryProvider);
    if (repository == null || _duplicating) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final onDuplicated = widget.onDuplicated;
    setState(() {
      _duplicating = true;
      _error = null;
    });
    try {
      final copyId = await repository.duplicateProject(
        widget.project.id,
        parentProjectId: _parentId,
        copyShares: _copyShares,
      );
      if (mounted) Navigator.of(context).pop();
      onDuplicated(copyId);
    } on Object catch (error) {
      _log.warning('Duplicating a project failed: ${error.runtimeType}');
      unawaited(HapticFeedback.heavyImpact());
      final text = projectChangeFailureText(
        l10n,
        error,
        ProjectChange.duplicate,
      );
      if (!mounted) {
        showFailureAfterClose(messenger, text);
        return;
      }
      setState(() {
        _duplicating = false;
        _error = text;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    return PopScope(
      canPop: !_duplicating,
      child: SingleChildScrollView(
        controller: widget.scrollController,
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PickerHeader(
              title: l10n.projectDuplicateTitle,
              actionLabel: _duplicating
                  ? l10n.projectDuplicating
                  : l10n.projectDuplicate,
              onAction: _duplicating ? null : () => unawaited(_duplicate()),
            ),
            if (_duplicating) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                l10n.projectDuplicateBody,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ParentProjectTile(
              label: parentProjectLabel(l10n, _parentId, projects),
              onTap: _duplicating ? null : () => unawaited(_pickParent()),
            ),
            SwitchListTile.adaptive(
              value: _copyShares,
              onChanged: _duplicating
                  ? null
                  : (value) => setState(() => _copyShares = value),
              title: Text(l10n.projectDuplicateShares),
              subtitle: Text(l10n.projectDuplicateSharesHint),
            ),
            if (_error case final error?) FormErrorText(error),
          ],
        ),
      ),
    );
  }
}
