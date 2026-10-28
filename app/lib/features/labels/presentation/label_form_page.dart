import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/router/pushed_pages.dart';
import 'package:vikunja_mobile/core/repositories/label_repository.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/common/presentation/app_bar_text_action.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/form_parts.dart';
import 'package:vikunja_mobile/features/common/presentation/list_note.dart';
import 'package:vikunja_mobile/features/common/presentation/loading_placeholder.dart';
import 'package:vikunja_mobile/features/common/presentation/screen_title.dart';
import 'package:vikunja_mobile/features/labels/application/label_groups.dart';
import 'package:vikunja_mobile/features/labels/presentation/label_change_failure.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/project_confirmations.dart';
import 'package:vikunja_mobile/features/sync/application/offline_state.dart';
import 'package:vikunja_mobile/features/sync/presentation/offline_notice.dart';
import 'package:vikunja_mobile/features/tasks/application/account_context_providers.dart';
import 'package:vikunja_mobile/features/tasks/application/label_providers.dart';
import 'package:vikunja_mobile/features/tasks/application/label_search.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/color_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/open/task_opener.dart';
import 'package:vikunja_mobile/features/tasks/presentation/rich_text/rich_html.dart';
import 'package:vikunja_mobile/features/tasks/presentation/rich_text/rich_link_actions.dart';

final _log = Logger('LabelForm');

/// The counter shows once this few code points are left.
const _counterFrom = 50;

/// A new label ([labelId] null), which starts with a random colour of the
/// web's palette, or one of the user's own labels: title, colour and,
/// once it exists, its description, which the editor saves on its own.
/// Save waits for the server, sends only what changed and stays open with
/// the reason when it refuses; a label that is gone closes the page.
class LabelFormPage extends ConsumerStatefulWidget {
  const new({this.labelId, super.key});

  final int? labelId;

  @override
  ConsumerState<LabelFormPage> createState() => _LabelFormPageState();
}

class _LabelFormPageState extends ConsumerState<LabelFormPage> {
  final _title = TextEditingController();
  final _customHex = TextEditingController();
  Label? _original;
  var _hexColor = '';
  var _initialHexColor = '';
  var _saving = false;
  var _closing = false;
  var _titleTouched = false;
  var _customHexInvalid = false;

  bool get _creating => widget.labelId == null;

  @override
  void initState() {
    super.initState();
    if (_creating) {
      _hexColor = _initialHexColor = randomLabelColor(Random());
      _customHex.text = _hexColor;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _customHex.dispose();
    super.dispose();
  }

  void _adopt(Label? label) {
    if (label == null || _original != null) return;
    _original = label;
    _title.text = label.title;
    _hexColor = _initialHexColor = label.hexColor;
    _customHex.text = label.hexColor;
  }

  LabelChanges _changes(Label original) {
    final title = _title.text.trim();
    return LabelChanges(
      title: _title.text == original.title || title == original.title
          ? null
          : title,
      hexColor: _hexColor == original.hexColor ? null : _hexColor,
    );
  }

  bool get _dirty {
    if (_creating) {
      return _title.text.trim().isNotEmpty || _hexColor != _initialHexColor;
    }
    final original = _original;
    return original != null && !_changes(original).isEmpty;
  }

  bool get _canSave =>
      !_saving &&
      !_customHexInvalid &&
      labelTitleProblem(_title.text) == null &&
      (_creating || _dirty);

  void _pickColor(String hex) => setState(() {
    _hexColor = hex;
    _customHex.text = hex;
    _customHexInvalid = false;
  });

  void _typeColor(String text) => setState(() {
    if (text.trim().isEmpty || text.trim() == '#') {
      _hexColor = '';
      _customHexInvalid = false;
      return;
    }
    final hex = normalizedHexColor(text);
    _customHexInvalid = hex == null;
    if (hex != null) _hexColor = hex;
  });

  Future<void> _save() async {
    final repository = ref.read(labelRepositoryProvider);
    if (repository == null || !_canSave) return;
    final original = _original;
    if (!_creating && original == null) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _saving = true);
    try {
      if (original == null) {
        await repository.create(
          NewLabel(title: _title.text.trim(), hexColor: _hexColor),
        );
      } else {
        await repository.update(original.id, _changes(original));
      }
      if (!mounted) return;
      setState(() => _closing = true);
      router.pop();
      unawaited(HapticFeedback.selectionClick());
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              original == null ? l10n.labelsCreated : l10n.labelsSaved,
            ),
          ),
        );
    } on Object catch (error) {
      _log.warning('Saving a label failed: ${error.runtimeType}');
      unawaited(HapticFeedback.heavyImpact());
      if (!mounted) return;
      setState(() => _saving = false);
      final text = labelChangeFailureText(
        l10n,
        error,
        _creating ? LabelChange.create : LabelChange.edit,
      );
      if (error is NotFound && !_creating) {
        setState(() => _closing = true);
        router.pop();
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _leaveIfConfirmed() async {
    final router = GoRouter.of(context);
    final discard = await confirmDiscardChanges(
      context,
      body: context.l10n.labelsDiscardBody,
    );
    if (discard && mounted) {
      setState(() => _closing = true);
      router.pop();
    }
  }

  Future<void> _editDescription(int labelId) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final saved = await context.pushPage<bool>(
      AppRoutes.labelDescription(labelId),
    );
    if (saved ?? false) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.descriptionEditorSaved)));
    }
  }

  void _openLink(String href) => unawaited(
    openRichTextLink(
      ref,
      href,
      openTask: _openTask,
      showMessage: (text) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(text(context.l10n))));
      },
    ),
  );

  void _openTask(int taskId) => unawaited(
    ref.read(taskOpenerProvider).openInActiveAccount(TaskById(taskId)),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = ref.watch(allLabelsProvider);
    final userId = ref.watch(activeUserIdProvider);
    final offline = ref.watch(offlineProvider) != null;
    final labelId = widget.labelId;
    final label = labelId == null
        ? null
        : labels.value?.where((label) => label.id == labelId).firstOrNull;
    if (labels.hasValue) _adopt(label);
    final original = _original;
    final own = _creating || (original != null && isOwnLabel(original, userId));
    final enabled = !_saving && own;

    final Widget body;
    if (_creating || (original != null && (label != null || _closing))) {
      body = _Form(
        titleController: _title,
        titleError: switch (labelTitleProblem(_title.text)) {
          NameProblem.blank when _titleTouched => l10n.labelsTitleRequired,
          _ => null,
        },
        customHexController: _customHex,
        customHexInvalid: _customHexInvalid,
        hexColor: _hexColor,
        enabled: enabled,
        notes: [
          if (offline) const OfflineNotice(),
          if (!own)
            ListNote(
              icon: Icons.lock_outline,
              text: l10n.labelsDescriptionCreatorOnly,
            ),
        ],
        description: label?.description,
        onEditDescription: label != null && enabled
            ? () => unawaited(_editDescription(label.id))
            : null,
        onTitleChanged: () => setState(() => _titleTouched = true),
        onColorPicked: _pickColor,
        onColorTyped: _typeColor,
        onSubmit: () => unawaited(_save()),
        onLink: _openLink,
        onTaskLink: _openTask,
      );
    } else if (labels.hasValue) {
      body = CenteredScrollView(
        child: EmptyState(
          icon: Icons.label_off_outlined,
          title: l10n.labelsGoneTitle,
          body: l10n.labelsGoneBody,
        ),
      );
    } else {
      body = CenteredScrollView(
        child: LoadingPlaceholder(label: l10n.labelsLoading),
      );
    }

    return PopScope(
      canPop: _closing || (!_dirty && !_saving),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) unawaited(_leaveIfConfirmed());
      },
      child: Scaffold(
        appBar: AppBar(
          title: ScreenTitle(_creating ? l10n.labelsNew : l10n.labelsEditTitle),
          actions: [
            if (own)
              AppBarTextAction(
                onPressed: _canSave ? () => unawaited(_save()) : null,
                child: Text(
                  _saving
                      ? l10n.labelsSaving
                      : _creating
                      ? l10n.labelsCreate
                      : l10n.labelsSave,
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
}

class _Form extends StatelessWidget {
  const new({
    required this.titleController,
    required this.titleError,
    required this.customHexController,
    required this.customHexInvalid,
    required this.hexColor,
    required this.enabled,
    required this.notes,
    required this.description,
    required this.onEditDescription,
    required this.onTitleChanged,
    required this.onColorPicked,
    required this.onColorTyped,
    required this.onSubmit,
    required this.onLink,
    required this.onTaskLink,
  });

  final TextEditingController titleController;
  final String? titleError;
  final TextEditingController customHexController;
  final bool customHexInvalid;
  final String hexColor;
  final bool enabled;
  final List<Widget> notes;

  /// As stored now, null for a label not created yet: the editor saves it
  /// on its own.
  final String? description;
  final VoidCallback? onEditDescription;
  final VoidCallback onTitleChanged;
  final ValueChanged<String> onColorPicked;
  final ValueChanged<String> onColorTyped;
  final VoidCallback onSubmit;
  final ValueChanged<String> onLink;
  final ValueChanged<int> onTaskLink;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final used = titleController.text.runes.length;
    final left = Label.maxTitleLength - used;
    final description = this.description;
    final hasDescription =
        description != null && descriptionFirstLine(description).isNotEmpty;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      children: [
        for (final note in notes)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: note,
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: titleController,
            enabled: enabled,
            autofocus: description == null,
            // Wraps, but Return saves instead of adding a line.
            maxLines: null,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [CodePointLimitFormatter(Label.maxTitleLength)],
            decoration: InputDecoration(
              labelText: l10n.labelsTitleLabel,
              errorText: titleError,
              errorMaxLines: 3,
              counterText: left <= _counterFrom
                  ? '$used/${Label.maxTitleLength}'
                  : null,
              semanticCounterText: left <= _counterFrom
                  ? l10n.labelsTitleRemaining(left)
                  : null,
            ),
            onChanged: (_) => onTitleChanged(),
            onSubmitted: (_) => onSubmit(),
          ),
        ),
        FormSectionTitle(l10n.labelsColour),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: IgnorePointer(
            ignoring: !enabled,
            child: ColorRow(
              value: hexColor,
              palette: newLabelColors,
              onChanged: onColorPicked,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: TextField(
            controller: customHexController,
            enabled: enabled,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[#0-9a-fA-F]')),
              LengthLimitingTextInputFormatter(7),
            ],
            decoration: InputDecoration(
              labelText: l10n.labelsCustomColour,
              prefixText: '#',
              helperText: l10n.labelsCustomColourHelper,
              helperMaxLines: 3,
              errorText: customHexInvalid
                  ? l10n.labelsCustomColourInvalid
                  : null,
              errorMaxLines: 3,
            ),
            onChanged: onColorTyped,
          ),
        ),
        FormSectionTitle(l10n.labelsDescription),
        if (description == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l10n.labelsDescriptionAfterCreate, style: muted),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SelectionArea(
              child: RichHtml(
                html: description,
                onLink: onLink,
                onTaskLink: onTaskLink,
                empty: Text(l10n.labelsNoDescription, style: muted),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: onEditDescription,
                icon: Icon(hasDescription ? Icons.edit_outlined : Icons.add),
                label: Text(
                  hasDescription
                      ? l10n.labelsEditDescription
                      : l10n.labelsAddDescription,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
